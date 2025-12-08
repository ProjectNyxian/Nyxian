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
#import <LindChain/ProcEnvironment/Surface/proc/userapi/copylist.h>
#include <sys/syscall.h>

DEFINE_SYSCALL_HANDLER(proctb)
{
    /* snapshot creation */
    proc_snapshot_t *snap;
    proc_list_err_t error = proc_snapshot_create(sys_proc_, &snap);
    if(error != PROC_LIST_OK)
    {
        *err = EPERM;
        return -1;
    }
    
    /* copy the buffer */
    *out_len = snap->count * sizeof(kinfo_proc_t);
    
    /* allocating outgoing payload (and copy in one step) */
    kern_return_t kr = mach_syscall_payload_create(snap->kp, *out_len, (vm_address_t*)out_payload);
    
    /* free the snapshot */
    proc_snapshot_free(snap);
    
    /* checking what the kernel wants to say */
    if(kr != KERN_SUCCESS)
    {
        /* idk where all that memory has gone */
        *err = ENOMEM;
        return -1;
    }
    
    return 0;
}
