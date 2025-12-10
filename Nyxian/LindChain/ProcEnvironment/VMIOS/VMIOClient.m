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
#import <LindChain/ProcEnvironment/panic.h>
#import <stdlib.h>

/* allocation helper for the kernel */
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
