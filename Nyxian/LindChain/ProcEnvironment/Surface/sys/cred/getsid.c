/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 cr4zyengineer

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#include <LindChain/ProcEnvironment/Surface/sys/cred/getsid.h>
#include <LindChain/ProcEnvironment/Surface/proc/lookup.h>
#include <LindChain/ProcEnvironment/Surface/proc/list.h>
#include <LindChain/ProcEnvironment/Surface/permit.h>

DEFINE_SYSCALL_HANDLER(getsid)
{
    pid_t pid = (pid_t)args[0];
    
    /* getting process */
    ksurface_proc_t *proc = NULL;
    ksurface_return_t ret = proc_for_pid(pid, &proc);
    
    /* sanity check */
    if(ret != SURFACE_SUCCESS ||
       proc == NULL)
    {
        sys_return_failure(EINVAL);
    }
    
    /* getting visibility */
    proc_visibility_t vis = get_proc_visibility(sys_proc_snapshot_);
    
    /* permission check */
    if(!can_see_process(sys_proc_snapshot_, proc, vis))
    {
        kvo_release(proc);
        sys_return_failure(EINVAL);
    }
    
    /* locking process read */
    kvo_rdlock(proc);
    
    /* getting sid */
    pid_t sid = proc->nyx.sid;
    
    /* doneee x3 */
    kvo_unlock(proc);
    kvo_release(proc);
    
    return sid;
}
