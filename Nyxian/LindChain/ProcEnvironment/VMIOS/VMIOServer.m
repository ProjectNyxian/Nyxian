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

#import <LindChain/ProcEnvironment/VMIOS/VMIOClient.h>
#import <LindChain/ProcEnvironment/VMIOS/VMIOServer.h>
#import <stdlib.h>
#import <pthread.h>

struct vm_io_server {
    mach_port_t port;
    pthread_t thread;
    volatile bool running;
};

typedef struct {
    mach_msg_header_t header;
    uint8_t body[sizeof(vm_io_request_t)];
    mach_msg_max_trailer_t trailer;
} vm_io_recv_buffer_t;

#pragma mark - vm io call wrappers

static inline bool vm_copy_in(mach_port_t mem_port,
                              vm_address_t address,
                              vm_size_t size)
{
    /* mapping */
    vm_address_t vm_address = VM_MIN_ADDRESS;
    kern_return_t kr = vm_map(mach_task_self(), &vm_address, size, 0, VM_FLAGS_ANYWHERE, mem_port, 0, FALSE, VM_PROT_READ | VM_PROT_WRITE, VM_PROT_READ | VM_PROT_WRITE, VM_INHERIT_DEFAULT);
    
    /* checking return */
    if(kr != KERN_SUCCESS)
    {
        return false;
    }
    
    /* copy */
    memcpy((void*)vm_address, (void*)address, size);
    
    /* deallocating */
    kr = vm_deallocate(mach_task_self(), vm_address, size);
    
    if(kr != KERN_SUCCESS)
    {
        /* idk what to do.. deallocation failed.. */
    }
    
    return true;
}

static inline bool vm_copy_out(mach_port_t mem_port,
                               vm_address_t address,
                               vm_size_t size)
{
    /* mapping */
    vm_address_t vm_address = VM_MIN_ADDRESS;
    kern_return_t kr = vm_map(mach_task_self(), &vm_address, size, 0, VM_FLAGS_ANYWHERE, mem_port, 0, FALSE, VM_PROT_READ | VM_PROT_WRITE, VM_PROT_READ | VM_PROT_WRITE, VM_INHERIT_DEFAULT);
    
    /* checking return */
    if(kr != KERN_SUCCESS)
    {
        return false;
    }
    
    /* copy */
    memcpy((void*)address, (void*)vm_address, size);
    
    /* deallocating */
    kr = vm_deallocate(mach_task_self(), vm_address, size);
    
    if(kr != KERN_SUCCESS)
    {
        /* idk what to do.. deallocation failed.. */
    }
    
    return true;
}

#pragma mark - the server it self

static inline void vm_io_reply(mach_msg_header_t *request,
                               mach_port_t reply_port,
                               mach_port_t reply_send_port,
                               bool succeeded,
                               uint8_t *tiny_payload,
                               uint8_t tiny_size)
{
    /* allocating a reply */
    vm_io_reply_t reply;
    memset(&reply, 0, sizeof(reply));
    
    /* setting reply data */
    reply.header.msgh_bits = MACH_MSGH_BITS_REMOTE(MACH_MSG_TYPE_MOVE_SEND_ONCE);
    reply.header.msgh_remote_port = request->msgh_remote_port;
    reply.header.msgh_local_port = MACH_PORT_NULL;
    reply.header.msgh_size = sizeof(reply);
    reply.header.msgh_id = request->msgh_id + 100;
    reply.body.msgh_descriptor_count = 0;
    
    /* storing vmio result */
    reply.suceeded = succeeded;
    reply.port = reply_send_port;
    
    /* check for reply port */
    if(reply_port != MACH_PORT_NULL)
    {
        reply.body.msgh_descriptor_count++;
        reply.header.msgh_bits |= MACH_MSGH_BITS_COMPLEX;
        reply.port_desc.type = MACH_MSG_PORT_DESCRIPTOR;
        reply.port_desc.name = reply_port;
        reply.port_desc.disposition = MACH_MSG_TYPE_COPY_SEND;
    }
    
    /* check for tiny payload presence */
    if(tiny_payload != NULL &&
       tiny_size > 0)
    {
        memcpy(reply.tiny_payload, tiny_payload, tiny_size);
        reply.tiny_size = tiny_size;
    }
    
    /* sending reply to child */
    mach_msg(&reply.header, MACH_SEND_MSG, sizeof(reply), 0, MACH_PORT_NULL, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
}

void *vm_io_worker_thread(void *ctx)
{
    /* getting the server */
    vm_io_server_t *server = (vm_io_server_t *)ctx;
    
    /* receive buffer to receive request from guest */
    vm_io_recv_buffer_t buffer = {};
    
    /*
     * setting options, this is what XPC cannot really give us
     * we simply tell XNU to always give us the identity of the process
     * requesting.
     */
    mach_msg_option_t options = MACH_RCV_MSG | MACH_RCV_LARGE | MACH_RCV_TRAILER_TYPE(MACH_MSG_TRAILER_FORMAT_0) | MACH_RCV_TRAILER_ELEMENTS(MACH_RCV_TRAILER_AUDIT);
    
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
        vm_io_request_t *req = (vm_io_request_t *)&buffer.header;
        
        /* switch through the types */
        mach_port_t reply_port = MACH_PORT_NULL;
        mach_port_t reply_send_port = MACH_PORT_NULL;
        bool success = false;
        
        uint8_t tiny_payload[UINT8_MAX];
        
        switch(req->type)
        {
            case kVMIORequestTypeCopyIn:
                success = vm_copy_in(req->port_desc.name, req->address, req->size);
                break;
            case kVMIORequestTypeCopyOut:
                success = vm_copy_out(req->port_desc.name, req->address, req->size);
                break;
            case kVMIORequestTypePortIn:
                reply_port = req->port;
                success = true;
                break;
            case kVMIORequestTypePortOut:
                reply_send_port = req->port_desc.name;
                mach_port_insert_right(mach_task_self(), reply_send_port, reply_send_port, MACH_MSG_TYPE_MAKE_SEND);
                success = true;
                break;
            case kVMIORequestTypeTinyCopyIn:
                memcpy((void*)tiny_payload, (void*)req->address, (size_t)req->tiny_size);
                break;
            case kVMIORequestTypeTinyCopyOut:
                memcpy((void*)req->address, (void*)req->tiny_payload, (size_t)req->tiny_size);
                break;
            default:
                break;
        }
        
        /* cleanup */
        if(MACH_MSGH_BITS_IS_COMPLEX(req->header.msgh_bits) &&
           req->body.msgh_descriptor_count > 0 &&
           req->port_desc.name != MACH_PORT_NULL)
        {
            mach_port_deallocate(mach_task_self(), req->port_desc.name);
        }
        
        vm_io_reply(&buffer.header, reply_port, reply_send_port, success, tiny_payload, req->tiny_size);
    }
    
    return NULL;
}

#pragma mark - server creation and destruction

vm_io_server_t *vm_io_server_create(void)
{
    return calloc(1, sizeof(vm_io_server_t));
}

void vm_io_server_destroy(vm_io_server_t *server)
{
    /* null pointer check */
    if(!server)
    {
        return;
    }
    
    /* stopping the server */
    vm_io_server_stop(server);
    
    /* releasing the memory the server was created with */
    free(server);
}

int vm_io_server_start(vm_io_server_t *server)
{
    /* null pointer check*/
    if(!server)
    {
        return -1;
    }
    
    kern_return_t kr;
    
    /* creating syscall server port */
    kr = mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &server->port);
    
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
        mach_port_deallocate(mach_task_self(), server->port);
        return -1;
    }
    
    /* setting limits on how many vmio requests can be queued at once */
    mach_port_limits_t limits = { .mpl_qlimit = 5 };
    
    /* setting it as a attribute MARK: fuck XPC */
    mach_port_set_attributes(mach_task_self(), server->port, MACH_PORT_LIMITS_INFO, (mach_port_info_t)&limits, MACH_PORT_LIMITS_INFO_COUNT);
    
    /* starting vmio server */
    server->running = true;
    pthread_create(&server->thread, NULL, vm_io_worker_thread, server);
    
    return 0;
}

void vm_io_server_stop(vm_io_server_t *server)
{
    /* null pointer check */
    if(!server)
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

mach_port_t vm_io_server_getport(vm_io_server_t *server)
{
    return server->port;
}
