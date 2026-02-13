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

#import <LindChain/ProcEnvironment/Surface/sys/compat/proctb.h>
#import <LindChain/ProcEnvironment/Surface/proc/list.h>
#include <sys/syscall.h>

DEFINE_SYSCALL_HANDLER(proctb)
{
    /* syscall header */
    sys_name("SYS_proctb");
    
    /* listing all processes */
    kinfo_proc_t *kpbuf = NULL;
    uint32_t count = 0;
    ksurface_return_t ret = proc_list(sys_proc_copy_, &kpbuf, &count);
    
    /* evaluating snapshot creation */
    switch(ret)
    {
        case SURFACE_NULLPTR:
            sys_return_failure(ENOMEM);
        case SURFACE_DENIED:
            sys_return_failure(EPERM);
        default:
            break;
    }
    
    /*
     * checking for integer overflow to prevent a buffer overflow,
     * which would lead to heap corruption.
     */
    if(count > UINT32_MAX / sizeof(kinfo_proc_t))
    {
        free(kpbuf);
        sys_return_failure(ENOMEM);
    }
    
    /* copying buffer, first tho we have to safe the size of the buffer */
    *out_len = count * sizeof(kinfo_proc_t);
    
    /* allocating outgoing payload (and copy in one step) */
    kern_return_t kr = mach_syscall_payload_create(kpbuf, *out_len, (vm_address_t*)out_payload);
    
    /* free the snapshot */
    free(kpbuf);
    
    /* checking what the kernel wants to say */
    if(kr != KERN_SUCCESS)
    {
        /* idk where all that memory has gone */
        sys_return_failure(ENOMEM);
    }
    
    sys_return;
}
