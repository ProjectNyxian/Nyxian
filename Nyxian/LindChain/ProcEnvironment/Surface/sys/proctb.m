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

#import <LindChain/ProcEnvironment/Surface/sys/proctb.h>
#import <LindChain/ProcEnvironment/Surface/proc/userapi/copylist.h>

DEFINE_SYSCALL_HANDLER(proctb)
{
    /* snapshot creation */
    proc_snapshot_t *snap;
    proc_list_err_t error = proc_snapshot_create(sys_proc_, &snap);
    if(error != PROC_LIST_OK)
    {
        return -1;
        *err = EPERM;
    }
    
    /* copy the buffer into NSData */
    *out_len = snap->count * sizeof(kinfo_proc_t);
    memcpy(out_payload, snap->kp, *out_len);
    
    /* free the snapshot */
    proc_snapshot_free(snap);
    
    return 0;
}
