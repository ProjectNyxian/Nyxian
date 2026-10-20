/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2025 - 2026 emexlab

 This file is part of Nyxian.

 Licensed under the emexLabs Public Source License, version 1.1
 (EPSL 1.1).

 Private use and modification are permitted under the license.
 Redistribution of source or binaries, modified or unmodified,
 requires prior written permission from emexLabs.

 External deployment is subject to the source-availability
 requirements and other conditions of the license.

 Provided "AS IS", without warranty, to the extent permitted by law.

 See LICENSE for the full license terms.
*/

#include <LindChain/ProcEnvironment/Surface/sys/proc/kill.h>
#include <LindChain/ProcEnvironment/Surface/proc/proc.h>
#include <LindChain/ProcEnvironment/Surface/proc/permit.h>
#include <LindChain/ProcEnvironment/Surface/proc/list.h>
#include <errno.h>

static bool kill_one_target(ksurface_proc_snapshot_t *caller_snapshot,
                            ksurface_proc_t *target,
                            int sig,
                            errno_t *err)
{
    if(!proc_snapshot_primitive_over_proc_allowed(caller_snapshot, target, kPEEntitlementFlagProcessKill, kPEEntitlementFlagNone, err))
    {
        return false;
    }
    
    kvo_rdlock(target);
    bool system_process = (target->bsd.kp_proc.p_flag & P_SYSTEM) != 0;
    kvo_unlock(target);
    
    if(system_process)
    {
        return false;
    }
    
    if(sig == 0)
    {
        return true;
    }
    
    return proc_kill(target, sig) == KERN_SUCCESS;
}

DEFINE_SYSCALL_HANDLER(kill)
{
    pid_t u_pid = (pid_t)args[0];
    int u_signal = (int)args[1];
    
    if(u_signal < 0 || u_signal >= NSIG)
    {
        sys_return_failure_with_errno(EINVAL);
    }
    
    if(u_pid > 0)
    {
        ksurface_proc_t *target = NULL;
        kern_return_t kr = proc_for_pid(u_pid, &target);
        if(kr != KERN_SUCCESS || target == NULL)
        {
            sys_return_failure_with_errno(ESRCH);
        }
        
        bool ok = kill_one_target(sys_proc_snapshot_, target, u_signal, err);
        kvo_release(target);
        if(!ok)
        {
            sys_return_failure_with_errno(errno ? errno : EPERM);
        }
        
        sys_return;
    }
    
    proc_flavour_t flavour;
    pid_t selector = 0;
    
    if(u_pid == 0)
    {
        flavour = PROC_FLV_PGID;
        selector = proc_getpgid(sys_proc_snapshot_);
    }
    else if(u_pid < -1)
    {
        flavour = PROC_FLV_PGID;
        selector = (pid_t)(-(int64_t)u_pid);
    }
    else
    {
        flavour = PROC_FLV_ALL;
    }
    
    kinfo_proc_t *kp = NULL;
    size_t len = 0;
    kern_return_t kr = proc_list(sys_proc_snapshot_, &kp, &len, flavour, selector);
    if(kr != KERN_SUCCESS)
    {
        sys_return_failure_with_errno(ENOMEM);
    }
    
    bool any = false;
    size_t count = len / sizeof(kinfo_proc_t);
    
    for(size_t i = 0; i < count; i++)
    {
        ksurface_proc_t *target = NULL;
        if(proc_for_pid(kp[i].kp_proc.p_pid, &target) != KERN_SUCCESS)
        {
            continue;
        }
        
        if(kill_one_target(sys_proc_snapshot_, target, u_signal, err))
        {
            any = true;
        }
        
        kvo_release(target);
    }
    
    free(kp);
    if(!any)
    {
        sys_return_failure_with_errno(ESRCH);
    }
    
    sys_return;
}
