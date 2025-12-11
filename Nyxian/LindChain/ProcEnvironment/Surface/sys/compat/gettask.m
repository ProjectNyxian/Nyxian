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
#import <LindChain/ProcEnvironment/tpod.h>

DEFINE_SYSCALL_HANDLER(gettask)
{
    /* check if environment supports tfp */
    if(!environment_supports_tfp())
    {
        *err = EPERM;
        return -1;
    }
    
    /* parse arguments */
    pid_t pid = (pid_t)args[0];
    
    /* check if the pid passed is the kernel process */
    bool isHost = pid == proc_getpid(kernel_proc_);
    
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
            *err = EFAULT;
            return -1;
        }
        
        /* locking target process */
        proc_read_lock(targetProc);
        
        /* getting entitlements of the target process */
        PEEntitlement targetEntitlements = proc_getentitlements(targetProc);
        
        /* unlocking target process */
        proc_unlock(targetProc);
        
        /* releasing target process, cuz were done now with it */
        proc_release(targetProc);
        
        /* checking if the caller process got the entitlement to use tfp */
        if(!entitlement_got_entitlement(proc_getentitlements(sys_proc_copy_), PEEntitlementTaskForPid))
        {
            *err = EPERM;
            return -1;
        }
        
        /* main permission check */
        if(!entitlement_got_entitlement(targetEntitlements, PEEntitlementGetTaskAllowed) ||
           !permitive_over_process_allowed(sys_proc_copy_, pid))
        {
            *err = EPERM;
            return -1;
        }
    }
    else
    {
        if(!entitlement_got_entitlement(proc_getentitlements(sys_proc_copy_), PEEntitlementTaskForPidHost))
        {
            *err = EPERM;
            return -1;
        }
    }
    
    /* asking tpod for tpo */
    TaskPortObject *tpo = get_tpo_for_pid(pid);
    
    /* null pointer check */
    if(tpo == NULL)
    {
        *err = EFAULT;
        return -1;
    }
    
    /* retaining port */
    mach_port_mod_refs(mach_task_self(), [tpo port], MACH_PORT_RIGHT_SEND, 1);
    
    /* allocating syscall payload */
    kern_return_t kr = mach_syscall_payload_create(NULL, sizeof(mach_port_t), (vm_address_t*)out_ports);
    
    /* mach return check */
    if(kr != KERN_SUCCESS)
    {
        *err = ENOMEM;
        return -1;
    }
    
    /* set port */
    (*out_ports)[0] = [tpo port];
    *out_ports_cnt = 1;
    
    return 0;
}
