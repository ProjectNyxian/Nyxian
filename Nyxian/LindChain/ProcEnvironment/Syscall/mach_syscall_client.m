/*
 Copyright (C) 2025 cr4zyengineer

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#import <Foundation/Foundation.h>
#import <LindChain/ProcEnvironment/VMIOS/VMIOServer.h>
#import <LindChain/ProcEnvironment/VMIOS/VMIOClient.h>
#import <LindChain/ProcEnvironment/Syscall/mach_syscall_client.h>
#import <LindChain/ProcEnvironment/Syscall/payload.h>
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <errno.h>

struct syscall_client {
    mach_port_t server_port;
    mach_port_t reply_port;
};

typedef struct {
    union {
        syscall_request_t req;
        syscall_reply_t   reply;
    };
    mach_msg_max_trailer_t trailer;
} syscall_msg_buffer_t;

syscall_client_t *syscall_client_create(mach_port_t port)
{
    /* allocate syscall client */
    syscall_client_t *client = malloc(sizeof(syscall_client_t));
    
    /* null pointer check */
    if(client == NULL)
    {
        return NULL;
    }
    
    kern_return_t kr;
    
    /* setting server port */
    client->server_port = port;
    
    /* allocate reply port for the syscall server to send back a message to */
    kr = mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &client->reply_port);
    
    /* XNU reply check */
    if(kr != KERN_SUCCESS)
    {
        /* deallocating on failure */
        mach_port_deallocate(mach_task_self(), client->server_port);
        free(client);
        return NULL;
    }
    
    return client;
}

void syscall_client_destroy(syscall_client_t *client)
{
    /* null pointer check */
    if(client == NULL)
    {
        return;
    }
    
    /* checking if the port is null */
    if(client->server_port != MACH_PORT_NULL)
    {
        /* deallocate port */
        mach_port_deallocate(mach_task_self(), client->server_port);
    }
    
    /* checking if the port is null */
    if (client->reply_port != MACH_PORT_NULL)
    {
        /* deallocate port */
        mach_port_deallocate(mach_task_self(), client->reply_port);
    }
    
    free(client);
}

/*
 * this symbol invokes the syscalls, it sends the request to the syscall server which then calls
 * the actual syscall
 */
int64_t syscall_invoke(syscall_client_t *client,
                       uint32_t syscall_num,
                       int64_t args[6])
{
    /* null pointer check */
    if(client == NULL)
    {
        errno = EFAULT;
        return -1;
    }
    
    /* once run vmios preparer */
    static mach_port_t vmio_port = MACH_PORT_NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        vm_io_server_t *server = vm_io_server_create();
        vm_io_server_start(server);
        vmio_port = vm_io_server_getport(server);
    });
    
    /* checking vmio port */
    if(vmio_port == MACH_PORT_NULL)
    {
        errno = EFAULT;
        return -1;
    }
    
    /* building syscall request :3c */
    syscall_msg_buffer_t buffer = {};
    
    /* stuffing the request ;3 */
    buffer.req.header.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, MACH_MSG_TYPE_MAKE_SEND_ONCE) | MACH_MSGH_BITS_COMPLEX;
    buffer.req.header.msgh_remote_port = client->server_port;
    buffer.req.header.msgh_local_port = client->reply_port;
    buffer.req.header.msgh_size = sizeof(syscall_request_t);
    buffer.req.header.msgh_id = syscall_num;
    
    /* sending vmio port to syscall server */
    buffer.req.body.msgh_descriptor_count = 1;
    buffer.req.vmio_desc.type = MACH_MSG_PORT_DESCRIPTOR;
    buffer.req.vmio_desc.name = vmio_port;
    buffer.req.vmio_desc.disposition = MACH_MSG_TYPE_COPY_SEND;
    
    /* telling cutie patootie ksurface what syscall we wanna call ^^ */
    buffer.req.syscall_num = syscall_num;
    
    /* checking for args to copy them possibly over, otherwise they stay nullified */
    if(args)
    {
        /* copy */
        memcpy(buffer.req.args, args, sizeof(buffer.req.args));
    }
    
    /*
     * now lets call da cutie >.<
     *
     * MARK: when using MACH_SEND_MSG | MACH_RCV_MSG together, the kernel
     * uses the same buffer for both operations. The receive buffer size
     * must be large enough to hold the reply plus any trailer.
     */
    kern_return_t kr = mach_msg(&buffer.req.header, MACH_SEND_MSG | MACH_RCV_MSG, sizeof(syscall_request_t), sizeof(buffer), client->reply_port, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
    
    /* checking for succession */
    if(kr != KERN_SUCCESS)
    {
        errno = EFAULT;
        return -1;
    }
    
    /* if the result is not 0 we set errno >~< */
    if(buffer.reply.result != 0)
    {
        errno = buffer.reply.err;
    }
    
    /* done ;3 */
    return buffer.reply.result;
}
