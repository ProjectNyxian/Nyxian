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

#include <LindChain/ProcEnvironment/Surface/sys/cred/setsid.h>
#include <LindChain/ProcEnvironment/Surface/proc/list.h>
#include <LindChain/ProcEnvironment/Surface/proc/lookup.h>
#include <errno.h>

DEFINE_SYSCALL_HANDLER(setsid)
{
    pid_t pid = proc_getpid(sys_proc_snapshot_);
    pid_t pgid = proc_getpgid(sys_proc_snapshot_);
    if(pgid == pid || proc_pgrp_exists(pid))
    {
        sys_return_failure_with_errno(EPERM);
    }
    
    kvo_wrlock(sys_proc_);
    proc_setsid(sys_proc_, pid);
    proc_setpgid(sys_proc_, pid);
    
    sys_proc_->bsd.kp_proc.p_flag &= ~P_CONTROLT;
    sys_proc_->bsd.kp_eproc.e_tdev = -1;
    sys_proc_->bsd.kp_eproc.e_tpgid = -1;
    kvo_unlock(sys_proc_);
    
    return pid;
}

DEFINE_SYSCALL_HANDLER(setpgid)
{
    pid_t u_pid = (pid_t)args[0];
    pid_t u_pgid = (pid_t)args[1];
    
    if(u_pgid < 0)
    {
        sys_return_failure_with_errno(EINVAL);
    }
    
    pid_t caller_pid = proc_getpid(sys_proc_snapshot_);
    pid_t caller_sid = proc_getsid(sys_proc_snapshot_);
    
    ksurface_proc_t *target = sys_proc_;
    bool release_target = false;
    
    if(u_pid != 0 && u_pid != caller_pid)
    {
        kern_return_t kr = proc_for_pid(u_pid, &target);
        if(kr != KERN_SUCCESS || target == NULL)
        {
            sys_return_failure_with_errno(ESRCH);
        }
        release_target = true;
        
        ksurface_proc_t *parent = NULL;
        kr = proc_parent_for_proc(target, &parent);
        bool is_child = kr == KERN_SUCCESS && parent == sys_proc_;
        if(parent != NULL)
        {
            kvo_release(parent);
        }
        
        if(!is_child)
        {
            kvo_release(target);
            sys_return_failure_with_errno(ESRCH);
        }
    }
    
    kvo_rdlock(target);
    pid_t target_pid = proc_getpid(target);
    pid_t target_sid = proc_getsid(target);
    pid_t old_pgid = proc_getpgid(target);
    kvo_unlock(target);
    
    if(target_sid != caller_sid)
    {
        if(release_target)
        {
            kvo_release(target);
        }
        sys_return_failure_with_errno(EPERM);
    }
    
    if(target_pid == target_sid)
    {
        if(release_target)
        {
            kvo_release(target);
        }
        sys_return_failure_with_errno(EPERM);
    }
    
    pid_t desired = (u_pgid == 0) ? target_pid : u_pgid;
    if(desired != target_pid)
    {
        if(!proc_pgrp_exists_in_session(desired, caller_sid))
        {
            if(release_target) kvo_release(target);
            sys_return_failure_with_errno(EPERM);
        }
    }
    else if(old_pgid != desired && proc_pgrp_exists(desired))
    {
        if(release_target) kvo_release(target);
        sys_return_failure_with_errno(EPERM);
    }
    
    kvo_wrlock(target);
    proc_setpgid(target, desired);
    kvo_unlock(target);
    
    if(release_target)
    {
        kvo_release(target);
    }
    
    sys_return;
}
