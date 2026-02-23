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

#import <LindChain/ProcEnvironment/Surface/sys/compat/gettask.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/Surface/permit.h>
#import <LindChain/ProcEnvironment/tfp.h>

DEFINE_SYSCALL_HANDLER(gettask)
{
    /* syscall wrapper */
    sys_name("SYS_gettask");
    
    /* parse arguments */
    pid_t pid = (pid_t)args[0];
    bool name_only = (bool)args[1];
    
    /* placeholder for target process */
    ksurface_proc_t *target = NULL;
    
    /* placeholder for error code */
    int errnov = 0;
    
    /*
     * claiming read onto task so no other process can
     * at the same time add their task port which could
     * lead to task port confusion, because of a tiny
     * window where a process could die while its
     * task port is requested and another process spawns
     * at the same time adding their task port which then
     * leads to this, permissions could be leaked by this
     * race by for example a root process handing off its
     * task port and it has the same port number as a port
     * that was unpriveleged before but not removed before.
     */
    task_rdlock();
    
    /* getting the target process */
    ksurface_return_t ret = proc_for_pid(pid, &target);
        
    /* checking if successful */
    if(ret != SURFACE_SUCCESS ||
        target == NULL)
    {
        errnov = ESRCH;
        goto out_unlock_failure;
    }
        
    /*
     * checks if target gives permissions to get the task port of it self
     * in the first place and if the process allows for it except if the
     * caller is a special process.
     */
    if(!permitive_over_pid_allowed(sys_proc_copy_, pid, YES, YES, YES, name_only ? PEEntitlementNone : PEEntitlementTaskForPid, name_only ? PEEntitlementNone : PEEntitlementGetTaskAllowed))
    {
        errnov = EPERM;
        goto out_proc_release_failure;
    }
    
    /* getting flavour */
    task_t exportTask = MACH_PORT_NULL;
    ksurface_return_t ksr = task_for_proc(target, TASK_KERNEL_PORT, &exportTask);
    
    if(ksr != SURFACE_SUCCESS)
    {
        /* failure?? */
        errnov = ESRCH;
        goto out_proc_release_failure;
    }
    
    /* getting port type */
    mach_port_type_t type;
    kern_return_t kr = mach_port_type(mach_task_self(), exportTask, &type);
    
    /* checking if port is valid in the first place */
    if(kr != KERN_SUCCESS ||
       type == MACH_PORT_TYPE_DEAD_NAME ||
       type == 0)
    {
        /* no rights to the task name? */
        errnov = ESRCH;
        goto out_destroy_task_port;
    }
    
    /* checking if pid of task port is valid */
    kr = pid_for_task(exportTask, &pid);
    if(kr != KERN_SUCCESS ||
       pid != proc_getpid(target))
    {
        errnov = ESRCH;
        goto out_destroy_task_port;
    }
    
    /* allocating syscall payload */
    kr = mach_syscall_payload_create(NULL, sizeof(mach_port_t), (vm_address_t*)out_ports);
    
    /* mach return check */
    if(kr != KERN_SUCCESS)
    {
        errnov = ENOMEM;
        goto out_destroy_task_port;
    }
    
    /* set task port to be send */
    (*out_ports)[0] = exportTask;
    *out_ports_cnt = 1;
    
    task_unlock();
    kvo_release(target);
    sys_return;
    
out_destroy_task_port:
    mach_port_deallocate(mach_task_self(), exportTask);
out_proc_release_failure:
    kvo_release(target);
out_unlock_failure:
    task_unlock();
    sys_return_failure(errnov);
}
