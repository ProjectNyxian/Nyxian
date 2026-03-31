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

#include <LindChain/ProcEnvironment/Surface/sys/compat/gettask.h>
#include <LindChain/ProcEnvironment/Surface/proc/proc.h>
#include <LindChain/ProcEnvironment/Surface/permit.h>
#include <LindChain/ProcEnvironment/tfp.h>

DEFINE_SYSCALL_HANDLER(gettask)
{    
    /* parse arguments */
    pid_t pid = (pid_t)args[0];
    bool name_only = (bool)args[1];
    
    /* getting the target process */
    ksurface_proc_t *target;
    ksurface_return_t ret = proc_for_pid(pid, &target);
    if(ret != SURFACE_SUCCESS)
    {
        sys_return_failure(ESRCH);
    }
        
    /*
     * checks if target gives permissions to get the task port of it self
     * in the first place and if the process allows for it except if the
     * caller is a special process.
     */
    if(!permitive_over_pid_allowed(sys_proc_snapshot_, pid, true, name_only ? PEEntitlementNone : PEEntitlementTaskForPid, name_only ? PEEntitlementNone : PEEntitlementGetTaskAllowed))
    {
        kvo_release(target);
        sys_return_failure(EPERM);
    }
    
    /* getting task port of flavour */
    task_t exportTask = MACH_PORT_NULL;
    ksurface_return_t ksr = proc_task_for_proc(target, name_only ? TASK_NAME_PORT : TASK_KERNEL_PORT, &exportTask);
    kvo_release(target);
    if(ksr != SURFACE_SUCCESS)
    {
        sys_return_failure(EACCES);
    }
    
    /* allocating syscall payload, so we can export it to the syscall caller */
    kern_return_t kr = mach_syscall_payload_create(NULL, sizeof(mach_port_t), (vm_address_t*)out_ports);
    if(kr != KERN_SUCCESS)
    {
        mach_port_deallocate(mach_task_self(), exportTask);
        sys_return_failure(ENOMEM);
    }
    
    /* set task port to be send */
    (*out_ports)[0] = exportTask;
    *out_ports_cnt = 1;
    
    sys_return;
}
