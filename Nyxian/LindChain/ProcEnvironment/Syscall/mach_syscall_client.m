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

#import <LindChain/ProcEnvironment/Syscall/mach_syscall_client.h>
#include <stdlib.h>
#include <string.h>

struct syscall_client {
    mach_port_t server_port;
    mach_port_t reply_port;
};

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
                       int64_t args[6],
                       void *in_payload,
                       uint32_t in_len,
                       void *out_payload,
                       uint32_t *out_len)
{
    /* null pointer check */
    if(client == NULL)
    {
        return -1;
    }
    
    /* building syscall request :3c */
    syscall_request_t req;
    
    /* nullfying request */
    memset(&req, 0, sizeof(req));
    
    /* stuffing the request ;3 */
    req.header.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND,MACH_MSG_TYPE_MAKE_SEND_ONCE);
    req.header.msgh_remote_port = client->server_port;
    req.header.msgh_local_port = client->reply_port;
    req.header.msgh_size = sizeof(req);
    req.header.msgh_id = syscall_num;
    
    /* telling cutie patootie XNU what syscall we wanna call ^^ */
    req.syscall_num = syscall_num;
    
    /* checking for args to copy them possibly over, otherwise they stay nullified */
    if(args)
    {
        /* copy */
        memcpy(req.args, args, sizeof(req.args));
    }
    
    /* checking for payload, if present writing it to the request */
    if(in_payload && in_len > 0)
    {
        /* copy again, rawrr */
        req.payload_len = (in_len > SYSCALL_MAX_PAYLOAD) ? SYSCALL_MAX_PAYLOAD : in_len;
        memcpy(req.payload, in_payload, req.payload_len);
    }
    
    /* allocatin the reply */
    syscall_reply_t reply;
    memset(&reply, 0, sizeof(reply));
    
    /* now lets call da cutie >.< */
    kern_return_t kr = mach_msg(&req.header, MACH_SEND_MSG | MACH_RCV_MSG, sizeof(req), sizeof(reply), client->reply_port, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
    
    /* checking for succession */
    if(kr != KERN_SUCCESS)
    {
        return -1;
    }
    
    /* payload validation */
    if(out_payload && out_len &&
       reply.payload_len > 0)
    {
        /* copying reply */
        uint32_t copy_len = (*out_len < reply.payload_len) ? *out_len : reply.payload_len;
        memcpy(out_payload, reply.payload, copy_len);
        *out_len = reply.payload_len;
    }
    
    /* done ;3 */
    return reply.result;
}
