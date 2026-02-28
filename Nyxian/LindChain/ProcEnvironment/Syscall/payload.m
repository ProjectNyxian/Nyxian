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

#import <LindChain/ProcEnvironment/Syscall/payload.h>
#include <assert.h>

kern_return_t mach_syscall_payload_create(void *ptr,
                                          size_t size,
                                          vm_address_t *vm_address)
{
    /* allocate using vm_allocate */
    kern_return_t kr = vm_allocate(mach_task_self(), vm_address, size, VM_FLAGS_ANYWHERE);
    
    /* null pointer check */
    if(kr == KERN_SUCCESS &&
       ptr != NULL)
    {
        /* you belong into here buffer pointed to by ptr ^^ */
        memcpy((void*)(*vm_address), ptr, size);
    }
    
    /* returning the kernels opinion of all this :/ (mom, i didnt broke the vase) */
    return kr;
}

bool mach_syscall_copy_in(task_t task,
                          size_t size,
                          kernelspace_pointer_t kptr,
                          userspace_pointer_t src)
{
    assert(kptr != NULL);
    
    if(src == NULL)
    {
        return false;
    }
    
    /*
     * reading userspace buffer into virtual kernel
     * space.
     */
    vm_size_t reply = 0;
    kern_return_t kr = vm_read_overwrite(task, (vm_address_t)src, size, (vm_address_t)kptr, &reply);
    
    /* checking if successful */
    if(kr != KERN_SUCCESS ||
       reply < size)
    {
        return false;
    }
    
    return true;
}

kernelspace_pointer_t mach_syscall_alloc_in(task_t task,
                                            size_t size,
                                            userspace_pointer_t src)
{
    if(src == NULL)
    {
        return NULL;
    }
    
    /* allocate kernelspace buffer */
    kernelspace_pointer_t kptr = malloc(size);
    
    /* sanity check */
    if(kptr == NULL)
    {
        return NULL;
    }
    
    /* zero out so this doesnt become a attack vector some day */
    bzero(kptr, size);
    
    /* trigger copy in */
    if(!mach_syscall_copy_in(task, size, kptr, src))
    {
        free(kptr);
        return NULL;
    }
    
    return kptr;
}

bool mach_syscall_copy_out(task_t task,
                           size_t size,
                           kernelspace_pointer_t kptr,
                           userspace_pointer_t dst)
{
    assert(kptr != NULL);
    
    if(dst == NULL)
    {
        return false;
    }
    
    /*
     * copy kernel buffer into virtualised userspace
     * dont worry tho we dont need to know how much
     * was written, because thats not our buisness.
     */
    kern_return_t kr = vm_write(task, (vm_address_t)dst, (vm_offset_t)kptr, (mach_msg_type_number_t)size);
    
    /* sanity check */
    if(kr != KERN_SUCCESS)
    {
        
        return false;
    }
    
    return true;
}

char *mach_syscall_copy_str_in(task_t task,
                               userspace_pointer_t src,
                               size_t len)
{
    /* copy upto lenght of string */
    size_t clen = 0;
    char buf = '\0';
    do {
        vm_size_t rlen = 0;
        kern_return_t kr = vm_read_overwrite(task, (vm_address_t)src + clen, sizeof(buf), (vm_address_t)&buf, &rlen);
        if(kr != KERN_SUCCESS)
        {
            return NULL;
        }
        
        if(clen >= len || buf == '\0')
        {
            break;
        }
        
        clen++;
    } while(buf != '\0');
    
    /* copy string */
    char *strBuf = malloc(clen);
    if(!mach_syscall_copy_in(task, clen, (kernelspace_pointer_t)strBuf, src))
    {
        free(strBuf);
        return NULL;
    }
    
    return strBuf;
}
