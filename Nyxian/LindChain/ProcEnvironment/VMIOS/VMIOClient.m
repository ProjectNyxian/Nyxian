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
    if(kr != KERN_SUCCESS)
    {
        /* for every malloc, I wanna see a free! */
        free(client_map);
        return NULL;
    }
    
    /* writing size to client_map so the caller's future vmio calls knows how to interpret it */
    client_map->map_size = map_size;
    
    /* lets give it to the caller :3 */
    return client_map;
}

void kvmio_dealloc(vm_io_client_map_t *map)
{
    /* null pointer check */
    if(map == NULL)
    {
        return;
    }
    
    /*
     * checking validity of map address
     * the map shall never have a null address
     * or a size of zero
     */
    if(map->map_address == VM_MIN_ADDRESS ||
       map->map_size == 0)
    {
        goto skip_and_free;
    }
    
    /* triggering deallocation */
    kern_return_t kr = vm_deallocate(mach_task_self(), map->map_address, map->map_size);
    
    /*
     * unlike allocation, if deallocation fails this means
     * something terrible happened and the kernel got compromised
     * so we panic immediately, panic is better than compromise
     */
    if(kr != KERN_SUCCESS)
    {
        environment_panic(); /* this shall never happen */
    }
    
skip_and_free:
    /* deallocating the map it self */
    free(map);
}
