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
