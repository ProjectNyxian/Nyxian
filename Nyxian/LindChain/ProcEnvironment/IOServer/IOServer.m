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

#import <LindChain/ProcEnvironment/IOServer/IOServer.h>
#import <pthread.h>
#import <stdlib.h>

struct io_server {
    mach_port_t port;
    pthread_t thread;
    volatile bool running;
};

typedef struct {
    mach_msg_header_t header;
    uint8_t body[sizeof(io_request_t)];
} io_recv_buffer_t;

static void io_server_send_reply(mach_msg_header_t *request,
                                 bool succeed,
                                 mach_port_t port,
                                 vm_size_t m_size,
                                 vm_size_t w_size)
{
    /* allocating a reply */
    io_reply_t reply;
    memset(&reply, 0, sizeof(reply));
    
    /* setting reply data */
    reply.header.msgh_bits = MACH_MSGH_BITS_REMOTE(MACH_MSG_TYPE_MOVE_SEND_ONCE);
    reply.header.msgh_remote_port = request->msgh_remote_port;
    reply.header.msgh_local_port = MACH_PORT_NULL;
    reply.header.msgh_size = sizeof(reply);
    reply.header.msgh_id = request->msgh_id + 100;
    reply.body.msgh_descriptor_count = 0;
    
    /* storing stuff into result */
    reply.success = succeed;
    reply.m_size = m_size;
    reply.w_size = w_size;
    
    /* payload validation */
    if(port != MACH_PORT_NULL)
    {
        reply.body.msgh_descriptor_count = 1;
        reply.header.msgh_bits |= MACH_MSGH_BITS_COMPLEX;
        reply.port.type = MACH_MSG_PORT_DESCRIPTOR;
        reply.port.name = port;
        reply.port.disposition = MACH_MSG_TYPE_COPY_SEND;
    }
    
    /* sending reply to ioclient */
    mach_msg(&reply.header, MACH_SEND_MSG, sizeof(reply), 0, MACH_PORT_NULL, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
}

void *io_server_worker_thread(void *arg)
{
    /* getting the server */
    io_server_t *server = (io_server_t*)arg;
    
    /* receive buffer to receive request from guest */
    io_recv_buffer_t buffer;
    
    /*
     * setting options, this is what XPC cannot really give us
     * we simply tell XNU to always give us the identity of the process
     * requesting.
     */
    mach_msg_option_t options = MACH_RCV_MSG | MACH_RCV_LARGE;
    
    /* worker thread request loop */
    while(server->running)
    {
        /* nullifying the buffer */
        memset(&buffer, 0, sizeof(buffer));
        
        /* waiting for the kernel to give us the childs request */
        kern_return_t kr = mach_msg(&buffer.header, options, 0, sizeof(buffer), server->port, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
        
        /* evaluating if the request received from the kernel was geniune */
        if(kr != KERN_SUCCESS)
        {
            if(!server->running)
            {
                /* in case the server is marked as not running we exit */
                break;
            }
            continue;
        }
        
        /* parsing request */
        io_request_t *req = (io_request_t *)&buffer.header;
        bool succeed = false;
        mach_port_t port = MACH_PORT_NULL;
        vm_size_t m_size = 0;
        vm_size_t w_size = 0;
        
        /* logic */
        // TODO: Implement
        
        /* reply */
        io_server_send_reply(&buffer.header, succeed, port, m_size, w_size);
    }
    
    return NULL;
}

io_server_t *io_server_create(void)
{
    /* allocating server */
    io_server_t *server = malloc(sizeof(io_server_t));
    
    /* null pointer check */
    if(server != NULL)
    {
        memset(server, 0, sizeof(io_server_t));
    }
    
    /* returning server */
    return server;
}

void io_server_destroy(io_server_t *server)
{
    /* null pointer check */
    if(server == NULL)
    {
        return;
    }
    
    /* stopping the server */
    io_server_stop(server);
    
    /* releasing the memory of the server */
    free(server);
}

int io_server_start(io_server_t *server)
{
    /* null pointer check */
    if(server == NULL)
    {
        return -1;
    }
    
    /* allocating server port for the IOClient */
    kern_return_t kr = mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &(server->port));
    
    /* mach return check */
    if(kr != KERN_SUCCESS)
    {
        return -1;
    }
    
    /* inserting port send right */
    kr = mach_port_insert_right(mach_task_self(), server->port, server->port, MACH_MSG_TYPE_MAKE_SEND);
    
    /* mach return check */
    if(kr != KERN_SUCCESS)
    {
        return -1;
    }
    
    /* setting limits on how many syscalls can be queued at once */
    mach_port_limits_t limits = { .mpl_qlimit = 32 };
    
    /* setting it as a attribute MARK: fuck XPC */
    mach_port_set_attributes(mach_task_self(), server->port, MACH_PORT_LIMITS_INFO, (mach_port_info_t)&limits, MACH_PORT_LIMITS_INFO_COUNT);
    
    /* starting syscall server */
    server->running = true;
    pthread_create(&server->thread, NULL, io_server_worker_thread, server);
    
    return 0;
}

void io_server_stop(io_server_t *server)
{
    /* null pointer check */
    if(server == NULL)
    {
        return;
    }
    
    /* stopping the server */
    server->running = false;
    
    /* checking if port is null */
    if(server->port != MACH_PORT_NULL)
    {
        /* destroying mach port */
        mach_port_deallocate(mach_task_self(), server->port);
        
        /* setting port */
        server->port = MACH_PORT_NULL;
    }
    
    /* stopping each thread of the server */
    pthread_join(server->thread, NULL);
}

mach_port_t io_server_get_port(io_server_t *server)
{
    /* null pointer check */
    if(server == NULL)
    {
        return MACH_PORT_DEAD;
    }
    
    /* return port */
    return server->port;
}
