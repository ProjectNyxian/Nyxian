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

#include <LindChain/ProcEnvironment/Surface/sys/cred/getsid.h>
#include <LindChain/ProcEnvironment/Surface/proc/lookup.h>
#include <LindChain/ProcEnvironment/Surface/proc/list.h>
#include <LindChain/ProcEnvironment/Surface/proc/permit.h>
#include <errno.h>

static kern_return_t proc_visible_target_for_pid(ksurface_proc_snapshot_t *caller,
                                                 pid_t pid,
                                                 ksurface_proc_t **target)
{
    kern_return_t kr = proc_for_pid(pid, target);
    if(kr != KERN_SUCCESS || *target == NULL)
    {
        return KERN_NOT_FOUND;
    }
    
    proc_visibility_t vis = proc_get_proc_visibility(caller);
    if(!proc_can_see_proc(caller, *target, vis))
    {
        kvo_release(*target);
        *target = NULL;
        return KERN_NOT_FOUND;
    }
    
    return KERN_SUCCESS;
}

DEFINE_SYSCALL_HANDLER(getsid)
{
    pid_t u_pid = (pid_t)args[0];
    if(u_pid == 0)
    {
        return proc_getsid(sys_proc_snapshot_);
    }
    
    ksurface_proc_t *target = NULL;
    kern_return_t kr = proc_visible_target_for_pid(sys_proc_snapshot_, u_pid, &target);
    if(kr != KERN_SUCCESS)
    {
        sys_return_failure_with_errno(ESRCH);
    }
    
    kvo_rdlock(target);
    pid_t sid = proc_getsid(target);
    kvo_unlock(target);
    kvo_release(target);
    
    return sid;
}

DEFINE_SYSCALL_HANDLER(getpgrp)
{
    return proc_getpgid(sys_proc_snapshot_);
}

DEFINE_SYSCALL_HANDLER(getpgid)
{
    pid_t u_pid = (pid_t)args[0];
    if(u_pid == 0)
    {
        return proc_getpgid(sys_proc_snapshot_);
    }
    
    ksurface_proc_t *target = NULL;
    kern_return_t kr = proc_visible_target_for_pid(sys_proc_snapshot_, u_pid, &target);
    if(kr != KERN_SUCCESS)
    {
        sys_return_failure_with_errno(ESRCH);
    }
    
    kvo_rdlock(target);
    pid_t pgid = proc_getpgid(target);
    kvo_unlock(target);
    kvo_release(target);
    
    return pgid;
}
