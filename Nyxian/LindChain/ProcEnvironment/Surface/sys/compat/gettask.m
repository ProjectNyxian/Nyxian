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
    /* check if environment supports tfp */
    if(!environment_supports_tfp())
    {
        sys_return_failure(ENOTSUP);
    }
    
    /* checking if the caller process got the entitlement to use tfp */
    if(!entitlement_got_entitlement(proc_getentitlements(sys_proc_copy_), PEEntitlementTaskForPid))
    {
        sys_return_failure(EPERM);
    }
    
    /* parse arguments */
    pid_t pid = (pid_t)args[0];
    
    /* check if the pid passed is the kernel process */
    bool isHost = (pid == proc_getpid(kernel_proc_));
    
    ksurface_proc_copy_t *target_copy = NULL;
    
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
        ksurface_proc_t *targetProc = proc_for_pid(pid);
        
        /* null pointer check */
        if(targetProc == NULL)
        {
            sys_return_failure(ESRCH);
        }
        
        /* making a copy of target process */
        target_copy = proc_copy_for_proc(targetProc, kProcCopyOptionStaticCopy);
        
        /* release the target process no matter what */
        proc_release(targetProc);
        
        /* checking if successful */
        if(target_copy == NULL)
        {
            sys_return_failure(ESRCH);
        }
        
        /*
         * main permission check
         *
         * checks if target gives permissions to get the task port of it self
         * in the first place and if the process allows for it except if the
         * caller is a special process.
         */
        if(!entitlement_got_entitlement(proc_getentitlements(sys_proc_copy_), PEEntitlementTaskForPidHost) &&
           (!entitlement_got_entitlement(proc_getentitlements(target_copy), PEEntitlementGetTaskAllowed) ||
            !permitive_over_process_allowed(sys_proc_copy_, pid)))
        {
            goto out_perm;
        }
    }
    else
    {
        if(!entitlement_got_entitlement(proc_getentitlements(sys_proc_copy_), PEEntitlementTaskForPidHost))
        {
            goto out_perm;
        }
        
        /* making a copy of target process */
        target_copy = proc_copy_for_proc(kernel_proc_, kProcCopyOptionStaticCopy);
        
        /* checking if successful */
        if(target_copy == NULL)
        {
            sys_return_failure(ESRCH);
        }
    }
    
    /* getting port type */
    mach_port_type_t type;
    kern_return_t kr = mach_port_type(mach_task_self(), target_copy->kproc.kcproc.task, &type);
    
    /* checking if port is valid in the first place */
    if(kr != KERN_SUCCESS ||
       type == MACH_PORT_TYPE_DEAD_NAME ||
       type == 0)
    {
        // No rights to the task name?
        goto out_esrch;
    }
    
    /* checking if pid of task port is valid */
    kr = pid_for_task(target_copy->kproc.kcproc.task, &pid);
    if(kr != KERN_SUCCESS ||
       pid != proc_getpid(target_copy))
    {
        goto out_esrch;
    }
    
    /* allocating syscall payload */
    kr = mach_syscall_payload_create(NULL, sizeof(mach_port_t), (vm_address_t*)out_ports);
    
    /* mach return check */
    if(kr != KERN_SUCCESS)
    {
        proc_copy_destroy(target_copy);
        sys_return_failure(ENOMEM);
    }
    
    /* retaining port */
    mach_port_mod_refs(mach_task_self(), target_copy->kproc.kcproc.task, MACH_PORT_RIGHT_SEND, 1);
    
    /* set port */
    (*out_ports)[0] = target_copy->kproc.kcproc.task;
    *out_ports_cnt = 1;
    
    proc_copy_destroy(target_copy);
    sys_return;

out_perm:
    proc_copy_destroy(target_copy);
    sys_return_failure(EPERM);
out_esrch:
    proc_copy_destroy(target_copy);
    sys_return_failure(ESRCH);
}
