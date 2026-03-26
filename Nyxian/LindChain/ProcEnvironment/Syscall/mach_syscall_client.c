/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 cr4zyengineer

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#include <LindChain/ProcEnvironment/Syscall/mach_syscall_client.h>
#include <LindChain/ProcEnvironment/Syscall/payload.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <pthread.h>
#include <assert.h>

struct syscall_client {
    mach_port_t server_port;
    pthread_key_t reply_port_key;
};

typedef struct {
    union {
        syscall_request_t req;
        syscall_reply_t   reply;
    };
    mach_msg_max_trailer_t trailer;
} syscall_msg_buffer_t;

static void reply_port_destructor(void *port_ptr)
{
    mach_port_t port = (mach_port_t)(uintptr_t)port_ptr;
    
    if(port != MACH_PORT_NULL)
    {
        mach_port_deallocate(mach_task_self(), port);
    }
}

static mach_port_t get_thread_reply_port(syscall_client_t *client)
{
    assert(client != NULL);
    
    mach_port_t port = (mach_port_t)(uintptr_t)pthread_getspecific(client->reply_port_key);
    
    if(port == MACH_PORT_NULL)
    {
        mach_port_options_t opts = {
            .flags = MPO_STRICT | MPO_REPLY_PORT
        };
        
        kern_return_t kr = mach_port_construct(mach_task_self(), &opts, 0, &port);
        
        if(kr != KERN_SUCCESS)
        {
            return MACH_PORT_NULL;
        }
        
        /*
         * set port as associated data of the thread
         * so we can clean it up once the thread dies.
         */
        pthread_setspecific(client->reply_port_key, (void*)(uintptr_t)port);
    }
    
    return port;
}

syscall_client_t *syscall_client_create(mach_port_t port)
{
    assert(port != MACH_PORT_NULL);
    
    syscall_client_t *client = malloc(sizeof(syscall_client_t));
    
    if(client == NULL)
    {
        return NULL;
    }
    
    client->server_port = port;
    
    /*
     * to make sure every thread gets the correct reply to its
     * syscall we create a pthread key so every thread gets
     * one syscall reply port, this port then gets cleaned up
     * when the thread dies. good and scalable!
     */
    if(pthread_key_create(&client->reply_port_key, reply_port_destructor) != 0)
    {
        free(client);
        return NULL;
    }
    
    return client;
}

void syscall_client_destroy(syscall_client_t *client)
{
    assert(client != NULL);
    
    if(client->server_port != MACH_PORT_NULL)
    {
        mach_port_deallocate(mach_task_self(), client->server_port);
    }
    
    /* shall destroy all ports in existence */
    pthread_key_delete(client->reply_port_key);
    
    free(client);
}

int64_t syscall_invoke(syscall_client_t *client,
                       uint32_t syscall_num,
                       int64_t *args,
                       mach_port_t *in_ports,
                       uint32_t in_ports_cnt,
                       mach_msg_type_name_t in_type,
                       mach_port_t **out_ports,
                       uint32_t out_ports_cnt)
{
    assert(client != NULL && args != NULL);
    
    /*
     * getting thread specific reply port to
     * use for environment syscalls, so there
     * wont be any ghost replies.
     */
    mach_port_t reply_port = get_thread_reply_port(client);
    if(reply_port == MACH_PORT_NULL)
    {
        errno = EAGAIN;
        return -1;
    }
    
    /*
     * the request stack memory buffer for
     * the host.
     */
    syscall_msg_buffer_t buffer;
    bzero(&buffer, sizeof(buffer));
    
    /* setting up request >~< */
    buffer.req.header.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, MACH_MSG_TYPE_MAKE_SEND_ONCE);
    buffer.req.header.msgh_remote_port = client->server_port;
    buffer.req.header.msgh_local_port = reply_port;
    buffer.req.header.msgh_size = sizeof(syscall_request_t);
    buffer.req.header.msgh_id = syscall_num;
    buffer.req.syscall_num = syscall_num;
    bcopy(args, buffer.req.args, sizeof(buffer.req.args));
    
    /*
     * this is used for mach and file descriptor
     * transmission, for simplicity, you cant
     * extract ports efficiently from the guest
     * using its task port, i attempted that
     * when i wrote copy_in and copy_out and
     * found that the soloutions are slow and
     * not feasible. on file descriptors there was
     * no other sulotion than directly using a ports
     * descriptor as mach is not BSD and file descriptors
     * is a bsd and not a mach concept but there is
     * a API called fileport that can be used to
     * on iOS convert a file descriptor into a
     * mach port which is like dup2 on a file
     * descriptor just that you create a mach port
     * which can restore the exact same file
     * descriptor later with the oppositing
     * fileport api.
     */
    if(in_ports &&
       in_ports_cnt > 0)
    {
        buffer.req.body.msgh_descriptor_count = 1;
        buffer.req.oolp.type = MACH_MSG_OOL_PORTS_DESCRIPTOR;
        buffer.req.header.msgh_bits |= MACH_MSGH_BITS_COMPLEX;
        buffer.req.oolp.disposition = in_type;
        buffer.req.oolp.address = in_ports;
        buffer.req.oolp.count = in_ports_cnt;
        buffer.req.oolp.copy = MACH_MSG_PHYSICAL_COPY;
    }
    
    /*
     * now lets call da cutie >.<
     *
     * MARK: when using MACH_SEND_MSG | MACH_RCV_MSG together, the kernel
     * uses the same buffer for both operations. The receive buffer size
     * must be large enough to hold the reply plus any trailer.
     */
    kern_return_t kr = mach_msg(&buffer.req.header, MACH_SEND_MSG | MACH_RCV_MSG, sizeof(syscall_request_t), sizeof(buffer), reply_port, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
    
    if(kr != KERN_SUCCESS)
    {
        errno = EBADMSG;
        return -1;
    }
    
    /*
     * the kernel can send ports back in a reply
     * which can contain file ports and mach ports
     * like task ports if the guest called SYS_gettask
     */
    if(buffer.reply.oolp.address != VM_MIN_ADDRESS)
    {
        /* TODO: more validation prolly needed */
        for(uint32_t c = 0; c < buffer.reply.oolp.count; c++)
        {
            (*out_ports)[c] = ((mach_port_t*)(buffer.reply.oolp.address))[c];
        }
        
        vm_deallocate(mach_task_self(), (mach_vm_address_t)buffer.reply.oolp.address, buffer.reply.oolp.count * sizeof(mach_port_t));
    }
    
    /*
     * the host usually provides a errno on failure
     * so we set it as usually and return with its
     * result.
     */
    errno = buffer.reply.err;
    return buffer.reply.result;
}
