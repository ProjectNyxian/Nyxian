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
#import <LindChain/ProcEnvironment/Surface/proc/rw.h>
#import <LindChain/ProcEnvironment/Surface/permit.h>
#import <LindChain/ProcEnvironment/tfp.h>

DEFINE_SYSCALL_HANDLER(gettask)
{
    /* syscall wrapper */
    sys_name("SYS_gettask");
    
    /* check if environment supports tfp */
    if(!environment_supports_tfp())
    {
        sys_return_failure(ENOTSUP);
    }
    
    /* parse arguments */
    pid_t pid = (pid_t)args[0];
    
    /* check if the pid passed is the caller them selves */
    bool isCaller = (pid == proc_getpid(sys_proc_copy_));
    
    /*
     * checking if the caller process got the entitlement to
     * use tfp or if its the caller it self requesting its
     * own task port which is allowed in any case.
     */
    if(!entitlement_got_entitlement(proc_getentitlements(sys_proc_copy_), PEEntitlementTaskForPid) &&
       !isCaller)
    {
        sys_return_failure(EPERM);
    }
    
    /* check if the pid passed is the kernel process */
    bool isHost = (pid == proc_getpid(kernel_proc_));
    
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
    proc_task_read_lock();
    
    /*
     * if host we can skip this crap :3
     *
     * and we shall skip it in that case,
     * because I dont wanna take another reference
     * of kernel_proc_, way too much CPU time for
     * a fact we already know lol.
     */
    if(!isHost)
    {
        /* getting the target process */
        target = proc_for_pid(pid);
        
        /* checking if successful */
        if(target == NULL)
        {
            sys_return_failure(ESRCH);
        }
        
        /*
         * checks if target gives permissions to get the task port of it self
         * in the first place and if the process allows for it except if the
         * caller is a special process.
         */
        if(!entitlement_got_entitlement(proc_getentitlements(sys_proc_copy_), PEEntitlementTaskForPidHost) &&
           ((!entitlement_got_entitlement(proc_getentitlements(target), PEEntitlementGetTaskAllowed) && !isCaller) ||
            !permitive_over_pid_allowed(sys_proc_copy_, pid)))
        {
            errnov = EPERM;
            goto out_proc_release_failure;
        }
    }
    else
    {
        /* checking if child is entitled */
        if(!entitlement_got_entitlement(proc_getentitlements(sys_proc_copy_), PEEntitlementTaskForPidHost))
        {
            errnov = EPERM;
            goto out_unlock_failure;
        }
        
        /* trying to retain kernel process */
        if(!proc_retain(kernel_proc_))
        {
            errnov = ESRCH;
            goto out_unlock_failure;
        }
        
        target = kernel_proc_;
    }
    
    /* getting port type */
    mach_port_type_t type;
    kern_return_t kr = mach_port_type(mach_task_self(), target->kproc.task, &type);
    
    /* checking if port is valid in the first place */
    if(kr != KERN_SUCCESS ||
       type == MACH_PORT_TYPE_DEAD_NAME ||
       type == 0)
    {
        /* no rights to the task name? */
        errnov = ESRCH;
        goto out_proc_release_failure;
    }
    
    /* checking if pid of task port is valid */
    kr = pid_for_task(target->kproc.task, &pid);
    if(kr != KERN_SUCCESS ||
       pid != proc_getpid(target))
    {
        errnov = ESRCH;
        goto out_proc_release_failure;
    }
    
    /* allocating syscall payload */
    kr = mach_syscall_payload_create(NULL, sizeof(mach_port_t), (vm_address_t*)out_ports);
    
    /* mach return check */
    if(kr != KERN_SUCCESS)
    {
        errnov = ENOMEM;
        goto out_proc_release_failure;
    }
    
    /* retaining port (so we as the kernel dont loose it) */
    mach_port_mod_refs(mach_task_self(), target->kproc.task, MACH_PORT_RIGHT_SEND, 1);
    
    /* set task port to be send */
    (*out_ports)[0] = target->kproc.task;
    *out_ports_cnt = 1;
    
    proc_task_unlock();
    proc_release(target);
    sys_return;
    
out_proc_release_failure:
    proc_release(target);
out_unlock_failure:
    proc_task_unlock();
    sys_return_failure(errnov);
}
