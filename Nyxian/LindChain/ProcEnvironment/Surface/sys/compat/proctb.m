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
    /* syscall wrapper */
    sys_name("SYS_proctb");
    
    /* snapshot creation */
    proc_snapshot_t *snap;
    proc_list_err_t error = proc_snapshot_create(sys_proc_copy_, &snap);
    
    /* evaluating snapshot creation */
    switch(error)
    {
        case PROC_LIST_OK:
            break;
        case PROC_LIST_ERR_PERM:
            sys_return_failure(EPERM);
        default:
            sys_return_failure(ENOMEM);
    }
    
    /*
     * checking for integer overflow to prevent a buffer overflow,
     * which would lead to heap corruption.
     */
    if(snap->count > UINT32_MAX / sizeof(kinfo_proc_t))
    {
        proc_snapshot_free(snap);
        sys_return_failure(ENOMEM);
    }
    
    /* copying buffer, first tho we have to safe the size of the buffer */
    *out_len = snap->count * sizeof(kinfo_proc_t);
    
    /* allocating outgoing payload (and copy in one step) */
    kern_return_t kr = mach_syscall_payload_create(snap->kp, *out_len, (vm_address_t*)out_payload);
    
    /* free the snapshot */
    proc_snapshot_free(snap);
    
    /* checking what the kernel wants to say */
    if(kr != KERN_SUCCESS)
    {
        /* idk where all that memory has gone */
        sys_return_failure(ENOMEM);
    }
    
    sys_return;
}
