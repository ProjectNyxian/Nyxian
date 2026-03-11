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

#import <LindChain/ProcEnvironment/Surface/sys/compat/procpath.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/Surface/proc/list.h>

DEFINE_SYSCALL_HANDLER(procpath)
{
    /* prepare arguments */
    pid_t pid = (pid_t)args[0];
    userspace_pointer_t buffer_ptr = (userspace_pointer_t)args[1];
    userspace_pointer_t size_ptr = (userspace_pointer_t)args[2];
    
    /* getting process */
    ksurface_proc_t *target = NULL;
    ksurface_return_t ret = proc_for_pid(pid, &target);
    
    /* sanity check */
    if(ret != SURFACE_SUCCESS ||
       target == NULL)
    {
        sys_return_failure(EINVAL);
    }
    
    /* getting visibility */
    proc_visibility_t vis = get_proc_visibility(sys_proc_snapshot_);
    
    /* permission check */
    if(!can_see_process(sys_proc_snapshot_, target, vis))
    {
        kvo_release(target);
        sys_return_failure(EINVAL);
    }
    
    size_t size = 0;
    if(!mach_syscall_copy_in(sys_task_, sizeof(size_t), &size, size_ptr))
    {
        kvo_release(target);
        sys_return_failure(EINVAL);
    }
    
    /* locking process read */
    kvo_rdlock(target);
    
    size_t buflen = strnlen(target->nyx.executable_path, PATH_MAX - 1) + 1;
    
    if(buflen > PATH_MAX)
    {
        kvo_unlock(target);
        kvo_release(target);
        sys_return_failure(EFAULT);
    }
    
    /*
     * getting output layout lenght. We have to add 1 more so the
     * nullterminator gets copied with it.
     */
    if(!mach_syscall_copy_out(sys_task_, buflen, target->nyx.executable_path, buffer_ptr))
    {
        kvo_unlock(target);
        kvo_release(target);
        sys_return_failure(EFAULT);
    }
    
    kvo_unlock(target);
    kvo_release(target);
    sys_return;
}
