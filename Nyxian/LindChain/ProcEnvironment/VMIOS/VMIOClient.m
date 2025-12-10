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

#import <LindChain/ProcEnvironment/VMIOS/VMIOServer.h>
#import <LindChain/ProcEnvironment/VMIOS/VMIOClient.h>
#import <LindChain/ProcEnvironment/panic.h>
#import <stdlib.h>

struct vm_io_client {
    mach_port_t server_port;
    mach_port_t reply_port;
};

typedef struct {
    union {
        vm_io_request_t req;
        vm_io_reply_t   reply;
    };
} vm_io_msg_buffer_t;

#pragma mark - connection and destruction

vm_io_client_t *kvmio_client_create(mach_port_t port)
{
    /* null port check */
    if(port == MACH_PORT_NULL)
    {
        return NULL;
    }
    
    /* allocating client */
    vm_io_client_t *client = calloc(1, sizeof(vm_io_client_t));
    
    /* null pointer check */
    if(client == NULL)
    {
        return NULL;
    }
    
    /* store server port */
    client->server_port = port;
    
    /* allocate reply port for the syscall server to send back a message to */
    kern_return_t kr = mach_port_allocate(mach_task_self(), MACH_PORT_RIGHT_RECEIVE, &client->reply_port);
    
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

void kvmio_client_destroy(vm_io_client_t *client)
{
    /* null pointer check */
    if(client == NULL)
    {
        goto out_panic;
    }
    
    /* validating client */
    if(client->server_port == MACH_PORT_NULL ||
       client->reply_port == MACH_PORT_NULL)
    {
        goto out_panic;
    }
    
    /* deallocating reply port */
    kern_return_t kr = mach_port_mod_refs(mach_task_self(), client->reply_port, MACH_PORT_RIGHT_RECEIVE, -1);
    
    /* checking what mach says */
    if(kr != KERN_SUCCESS)
    {
        goto out_panic;
    }
    
    /* deallocating client it self */
    free(client);
    return;
    
out_panic:
    environment_panic(); /* shall never happen */
}

#pragma mark - allocation helper for the kernel

vm_io_client_map_t *kvmio_alloc(vm_size_t map_size)
{
    /* null size check */
    if(map_size == 0)
    {
        return NULL;
    }
    
    /* allocate map reference */
    vm_io_client_map_t *client_map = calloc(1, sizeof(vm_io_client_map_t));
    
    /* null pointer check */
    if(client_map == NULL)
    {
        return NULL;
    }
    
    /* allocating size */
    kern_return_t kr = vm_allocate(mach_task_self(), &(client_map->map_address), map_size, VM_FLAGS_ANYWHERE);
    
    /* checking what mach says :3c */
    if(kr != KERN_SUCCESS ||
       client_map->map_address == VM_MIN_ADDRESS)
    {
        goto out_free_map;
    }
    
    /* writing size to client_map so the caller's future vmio calls knows how to interpret it */
    client_map->map_size = map_size;
    
    /* now we have to create a memory port */
    memory_object_size_t entry_len = map_size;
    kr = mach_make_memory_entry_64(mach_task_self(), &entry_len, (mach_vm_address_t)client_map->map_address, VM_PROT_READ | VM_PROT_WRITE | MAP_MEM_VM_SHARE, &(client_map->mem_port), MACH_PORT_NULL);
    
    /* checking what mach says again, stop yelling mach its okay */
    if(kr != KERN_SUCCESS ||
       client_map->mem_port == MACH_PORT_NULL)
    {
        goto out_dealloc_map;
    }
    
    /* checking if the size we got matches up */
    if(entry_len < client_map->map_size)
    {
        goto out_dealloc_port;
    }
    
    /* lets give it to the caller :3 */
    return client_map;
    
    /* bunny, jumps into death :c */
out_dealloc_port:
    kr = mach_port_deallocate(mach_task_self(), client_map->mem_port);
    if(kr != KERN_SUCCESS)
    {
        environment_panic(); /* this shall never happen */
    }
out_dealloc_map:
    kr = vm_deallocate(mach_task_self(), client_map->map_address, map_size);
    if(kr != KERN_SUCCESS)
    {
        environment_panic(); /* this shall never happen */
    }
out_free_map:
    /* for every malloc, I wanna see a free! */
    free(client_map);
    return NULL;
}

void kvmio_dealloc(vm_io_client_map_t *map)
{
    /* null pointer check */
    if(map == NULL)
    {
        goto out_panic;
    }
    
    /* defining kernel return */
    kern_return_t kr = KERN_FAILURE;
    
    /* checking for port */
    if(map->mem_port != MACH_PORT_NULL)
    {
        /* deallocating port */
        kr = mach_port_deallocate(mach_task_self(), map->mem_port);
        if(kr != KERN_SUCCESS)
        {
            goto out_panic;
        }
    }
    else
    {
        goto out_panic;
    }
    
    /* checking memory */
    if(map->map_address != VM_MIN_ADDRESS &&
       map->map_size != 0)
    {
        /* deallocating map */
        kr = vm_deallocate(mach_task_self(), map->map_address, map->map_size);
        if(kr != KERN_SUCCESS)
        {
            goto out_panic;
        }
    }
    else
    {
        goto out_panic;
    }
    
    /* final free */
    free(map);
    
    return;
    
out_panic:
    /*
     * some of you would say why are you doing this shit,
     * its because it shall never fail, if this symbol fails
     * it means that there is a bug in my kernel virtualization
     * layer.
     */
    environment_panic(); /* this shall never happen*/
}

#pragma mark - internal vmio call invocation symbol

static inline bool kvmio_call_invoke_internal(vm_io_client_t *client,
                                              mach_port_t port_send,
                                              mach_port_t port_req,
                                              vm_address_t address,
                                              vm_size_t size,
                                              vm_io_request_type_t type,
                                              mach_port_t *port_recv,
                                              mach_port_t *port_send_recv,
                                              uint8_t *tiny_payload,
                                              uint8_t tiny_size,
                                              uint8_t *tiny_out,
                                              uint8_t *tiny_out_size)
{
    /* null pointer check */
    if(client == NULL)
    {
        return false;
    }
    
    /* msg buffer */
    vm_io_msg_buffer_t buffer = {};
    
    /* stuffing the request ;3 */
    buffer.req.header.msgh_bits = MACH_MSGH_BITS(MACH_MSG_TYPE_COPY_SEND, MACH_MSG_TYPE_MAKE_SEND_ONCE);
    buffer.req.header.msgh_remote_port = client->server_port;
    buffer.req.header.msgh_local_port = client->reply_port;
    buffer.req.header.msgh_size = sizeof(vm_io_request_t);
    buffer.req.header.msgh_id = type;
    buffer.req.body.msgh_descriptor_count = 0;
    buffer.req.address = address;
    buffer.req.size = size;
    buffer.req.type = type;
    buffer.req.port = port_req;
    
    /* now checking for port */
    if(port_send != MACH_PORT_NULL)
    {
        buffer.req.header.msgh_bits |= MACH_MSGH_BITS_COMPLEX;
        buffer.req.body.msgh_descriptor_count++;
        buffer.req.port_desc.type = MACH_MSG_PORT_DESCRIPTOR;
        buffer.req.port_desc.name = port_send;
        buffer.req.port_desc.disposition = MACH_MSG_TYPE_COPY_SEND;
    }
    
    /* checking for tiny ^^ */
    if(tiny_payload != NULL &&
       tiny_size > 0)
    {
        memcpy(buffer.req.tiny_payload, tiny_payload, tiny_size);
        buffer.req.tiny_size = tiny_size;
    }
    
    /* sending the message */
    kern_return_t kr = mach_msg(&buffer.req.header, MACH_SEND_MSG | MACH_RCV_MSG, sizeof(vm_io_request_t), sizeof(buffer), client->reply_port, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
    
    /* checking for tiny ^^ */
    if(buffer.reply.tiny_size > 0 &&
       tiny_out != NULL &&
       tiny_out_size > 0)
    {
        /* copying tiny back */
        memcpy(buffer.req.tiny_payload, tiny_payload, tiny_size);
        buffer.req.tiny_size = tiny_size;
    }
    
    /* checking kernel return */
    if(kr != KERN_SUCCESS ||
       !buffer.reply.suceeded)
    {
        return false;
    }
    
    /* storing results if applicable */
    if(port_recv != NULL)
    {
        *port_recv = buffer.reply.port_desc.name;
    }
    
    if(port_send_recv != NULL)
    {
        *port_send_recv = buffer.reply.port;
    }
    
    return true;
}


#pragma mark - kvmio api

/* FUCK WE NEED WAY MORE VALIDATION?!?!?! */
kvmio_error_t kvmio_copy_in(vm_io_client_t *client,
                            vm_io_client_map_t *map,
                            vm_address_t iovm_address)
{
    bool succeeded = kvmio_call_invoke_internal(client, map->mem_port, MACH_PORT_NULL, iovm_address, map->map_size, kVMIORequestTypeCopyIn, NULL, NULL, NULL, 0, NULL, NULL);
    return succeeded ? kVMIOClientErrorSuccess : kVMIOClientErrorFailure;
}

kvmio_error_t kvmio_copy_out(vm_io_client_t *client,
                             vm_io_client_map_t *map,
                             vm_address_t iovm_address)
{
    bool succeeded = kvmio_call_invoke_internal(client, map->mem_port, MACH_PORT_NULL, iovm_address, map->map_size, kVMIORequestTypeCopyOut, NULL, NULL, NULL, 0, NULL, NULL);
    return succeeded ? kVMIOClientErrorSuccess : kVMIOClientErrorFailure;
}

kvmio_error_t kvmio_port_in(vm_io_client_t *client,
                            mach_port_t port_krnl,
                            mach_port_t *port_iovm)
{
    bool succeeded = kvmio_call_invoke_internal(client, port_krnl, MACH_PORT_NULL, VM_MIN_ADDRESS, 0, kVMIORequestTypePortIn, NULL, port_iovm, NULL, 0, NULL, NULL);
    return succeeded ? kVMIOClientErrorSuccess : kVMIOClientErrorFailure;
}

kvmio_error_t kvmio_port_out(vm_io_client_t *client,
                             mach_port_t *port_krnl,
                             mach_port_t port_iovm)
{
    bool succeeded = kvmio_call_invoke_internal(client, MACH_PORT_NULL, port_iovm, VM_MIN_ADDRESS, 0, kVMIORequestTypePortOut, port_krnl, NULL, NULL, 0, NULL, NULL);
    return succeeded ? kVMIOClientErrorSuccess : kVMIOClientErrorFailure;
}

kvmio_error_t kvmio_tiny_copy_in(vm_io_client_t *client, vm_address_t krnl_address, vm_size_t krnl_size, vm_address_t iovm_address)
{
    bool succeeded = kvmio_call_invoke_internal(client, MACH_PORT_NULL, MACH_PORT_NULL, iovm_address, 0, kVMIORequestTypeTinyCopyIn, NULL, NULL, (void*)krnl_address, krnl_size, NULL, NULL);
    return succeeded ? kVMIOClientErrorSuccess : kVMIOClientErrorFailure;
}

kvmio_error_t kvmio_tiny_copy_out(vm_io_client_t *client, vm_address_t krnl_address, vm_size_t krnl_size, vm_address_t iovm_address)
{
    bool succeeded = kvmio_call_invoke_internal(client, MACH_PORT_NULL, MACH_PORT_NULL, VM_MIN_ADDRESS, 0, kVMIORequestTypeTinyCopyOut, NULL, NULL, NULL, 0, NULL, NULL);
    return succeeded ? kVMIOClientErrorSuccess : kVMIOClientErrorFailure;
}
