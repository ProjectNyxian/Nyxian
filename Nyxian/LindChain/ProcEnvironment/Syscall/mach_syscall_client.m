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

#import <LindChain/Debugger/Utils.h>
#import <LindChain/ProcEnvironment/Syscall/mach_syscall_client.h>
#import <LindChain/ProcEnvironment/Syscall/payload.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>
#include <pthread.h>

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

syscall_client_t *syscall_client_create(mach_port_t port)
{
    syscall_client_t *client = malloc(sizeof(syscall_client_t));
    
    if(client == NULL)
    {
        return NULL;
    }
    
    client->server_port = port;
    
    if(pthread_key_create(&client->reply_port_key, reply_port_destructor) != 0)
    {
        free(client);
        return NULL;
    }
    
    return client;
}

static mach_port_t get_thread_reply_port(syscall_client_t *client)
{
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
        
        pthread_setspecific(client->reply_port_key, (void*)(uintptr_t)port);
    }
    
    return port;
}

void syscall_client_destroy(syscall_client_t *client)
{
    assert(client != NULL);
    
    /* checking if the port is null */
    if(client->server_port != MACH_PORT_NULL)
    {
        /* deallocate port */
        mach_port_deallocate(mach_task_self(), client->server_port);
    }
    
    pthread_key_delete(client->reply_port_key);
    
    free(client);
}

/*
 * this symbol invokes the syscalls, it sends the request to the syscall server which then calls
 * the actual syscall
 */
int64_t syscall_invoke(syscall_client_t *client,
                       uint32_t syscall_num,
                       int64_t *args,
                       mach_port_t *in_ports,
                       uint32_t in_ports_cnt,
                       mach_msg_type_name_t in_type,
                       mach_port_t **out_ports,
                       uint32_t out_ports_cnt)
{
    assert(client != NULL);
    
    mach_port_t reply_port = get_thread_reply_port(client);
    if(reply_port == MACH_PORT_NULL)
    {
        errno = EAGAIN;
        return -1;
    }
    
    /* building syscall request :3c */
    syscall_msg_buffer_t buffer;
    
    /* nullfying buffer */
    bzero(&buffer, sizeof(buffer));
    
    /* stuffing the request ;3 */
    buffer.req.header.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, MACH_MSG_TYPE_MAKE_SEND_ONCE);
    buffer.req.header.msgh_remote_port = client->server_port;
    buffer.req.header.msgh_local_port = reply_port;
    buffer.req.header.msgh_size = sizeof(syscall_request_t);
    buffer.req.header.msgh_id = syscall_num;
    
    /* telling cutie patootie ksurface what syscall we wanna call ^^ */
    buffer.req.syscall_num = syscall_num;
    
    /* checking for args to copy them possibly over, otherwise they stay nullified */
    if(args)
    {
        /* copy */
        memcpy(buffer.req.args, args, sizeof(buffer.req.args));
    }
    
    /* checking for mach ports, if present creating ool descriptor for mach ports */
    buffer.req.oolp.type = MACH_MSG_OOL_PORTS_DESCRIPTOR;
    
    if(in_ports &&
       in_ports_cnt > 0)
    {
        buffer.req.body.msgh_descriptor_count = 1;
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
    
    /* checking for succession */
    if(kr != KERN_SUCCESS)
    {
        return -1;
    }
    
    /* checking for output ports */
    if(buffer.reply.oolp.address != VM_MIN_ADDRESS)
    {
        /* copying ports */
        for(uint32_t c = 0; c < buffer.reply.oolp.count; c++)
        {
            (*out_ports)[c] = ((mach_port_t*)(buffer.reply.oolp.address))[c];
        }
        
        /* deallocating that nasty mess */
        vm_deallocate(mach_task_self(), (mach_vm_address_t)buffer.reply.oolp.address, buffer.reply.oolp.count * sizeof(mach_port_t));
    }
    
    /* just set errno */
    errno = buffer.reply.err;
    
    /* done ;3 */
    return buffer.reply.result;
}
