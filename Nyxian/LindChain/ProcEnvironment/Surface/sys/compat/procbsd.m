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

#import <LindChain/ProcEnvironment/Surface/sys/compat/procbsd.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/Surface/proc/list.h>
#import <LindChain/ProcEnvironment/Surface/proc/rw.h>

DEFINE_SYSCALL_HANDLER(procbsd)
{
    /* syscall wrapper */
    sys_name("SYS_procbsd");
    
    pid_t pid = (pid_t)args[0];
    
    /* getting process */
    ksurface_proc_t *proc = proc_for_pid(pid);
    
    /* sanity check */
    if(proc == NULL)
    {
        sys_return_failure(EINVAL);
    }
    
    /* getting visibility */
    proc_visibility_t vis = get_proc_visibility(sys_proc_copy_);
    
    /* permission check */
    if(!can_see_process(sys_proc_copy_, proc, vis))
    {
        KVOBJECT_RELEASE(proc);
        sys_return_failure(EINVAL);
    }
    
    /* setting output lenght to payload size */
    *out_len = sizeof(kinfo_proc_t);
    
    /* locking process read */
    proc_read_lock(proc);
    
    /* copying buffer into mach syscall payload */
    kern_return_t kr = mach_syscall_payload_create(&(proc->kproc.kcproc.bsd), sizeof(kinfo_proc_t), (vm_address_t*)out_payload);
    
    /* doneee x3 */
    proc_unlock(proc);
    KVOBJECT_RELEASE(proc);
    
    if(kr == KERN_SUCCESS)
    {
        sys_return;
    }
    else
    {
        sys_return_failure(EFAULT);
    }
}
