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

#include <LindChain/ProcEnvironment/Surface/sys/cred/setuid.h>
#include <LindChain/ProcEnvironment/Surface/trust/entitlement.h>
#include <LindChain/ProcEnvironment/Surface/proc/proc.h>

ksurface_proc_ucred_backup_t proc_make_ucred_backup(ksurface_proc_t *proc)
{
    return (ksurface_proc_ucred_backup_t){
        .ruid = proc_getruid(proc),
        .euid = proc_geteuid(proc),
        .svuid = proc_getsvuid(proc),
        .rgid = proc_getrgid(proc),
        .egid = proc_getegid(proc),
        .svgid = proc_getsvgid(proc),
    };
}

void proc_set_sugid_if_applicable(ksurface_proc_t *proc,
                                  ksurface_proc_ucred_backup_t backup)
{
    if(proc->bsd.kp_proc.p_flag & P_SUGID)
    {
        return;
    }
    
    if(proc_getruid(proc) != backup.ruid  ||
       proc_geteuid(proc) != backup.euid  ||
       proc_getsvuid(proc) != backup.svuid ||
       proc_getrgid(proc) != backup.rgid  ||
       proc_getegid(proc) != backup.egid  ||
       proc_getsvgid(proc) != backup.svgid)
    {
        proc->bsd.kp_proc.p_flag |= P_SUGID;
    }
}

bool proc_is_privileged(ksurface_proc_t *proc)
{
    /* Checking if process is entitled to elevate. */
    if(entitlement_got_entitlement(proc_getentitlements(proc), kPEEntitlementFlagProcessElevate))
    {
        return true;
    }
    
    /* It's not, so we check if the process is root. */
    return proc_getruid(proc) == 0;
}

DEFINE_SYSCALL_HANDLER(setuid)
{
    /* syscall wrapper */
    kvo_wrlock(sys_proc_);
    ksurface_proc_ucred_backup_t ucred_backup = proc_make_ucred_backup(sys_proc_);
    
    /* getting args, nu checks needed the syscall server does them */
    uid_t u_uid = (uid_t)args[0];
    
    /* checking if process is priveleged enough */
    if(proc_is_privileged(sys_proc_))
    {
        /* process is privelegedm updating credentials */
        proc_setruid(sys_proc_, u_uid);
        proc_seteuid(sys_proc_, u_uid);
        proc_setsvuid(sys_proc_, u_uid);
        
        /* update and return */
        goto out_update;
    }
    else
    {
        /* setting if ruid or svuid matches the wished uid */
        if(u_uid == proc_getruid(sys_proc_) ||
           u_uid == proc_getsvuid(sys_proc_))
        {
            /* updating credentials */
            proc_seteuid(sys_proc_, u_uid);
            
            /* update and return */
            goto out_update;
        }
    }
    
    /* setting errno on failure */
    kvo_unlock(sys_proc_);
    sys_return_failure_with_errno(EPERM);
    
out_update:
    proc_set_sugid_if_applicable(sys_proc_, ucred_backup);
    kvo_unlock(sys_proc_);
    sys_return;
}

DEFINE_SYSCALL_HANDLER(seteuid)
{
    /* syscall wrapper */
    kvo_wrlock(sys_proc_);
    ksurface_proc_ucred_backup_t ucred_backup = proc_make_ucred_backup(sys_proc_);
    
    /* getting args, nu checks needed the syscall server does them */
    uid_t u_euid = (uid_t)args[0];
    
    /* checking if process is priveleged enough */
    if(proc_is_privileged(sys_proc_))
    {
        /* updating credentials */
        proc_seteuid(sys_proc_, u_euid);
        
        /* update and return */
        goto out_update;
    }
    else
    {
        if(u_euid == proc_getruid(sys_proc_) ||
           u_euid == proc_geteuid(sys_proc_) ||
           u_euid == proc_getsvuid(sys_proc_))
        {
            /* updating credentials */
            proc_seteuid(sys_proc_, u_euid);
            
            /* update and return */
            goto out_update;
        }
    }
    
    /* setting errno on failure */
    kvo_unlock(sys_proc_);
    sys_return_failure_with_errno(EPERM);
    
out_update:
    proc_set_sugid_if_applicable(sys_proc_, ucred_backup);
    kvo_unlock(sys_proc_);
    sys_return;
}

DEFINE_SYSCALL_HANDLER(setreuid)
{
    /* syscall wrapper */
    kvo_wrlock(sys_proc_);
    ksurface_proc_ucred_backup_t ucred_backup = proc_make_ucred_backup(sys_proc_);
    
    /* getting args, nu checks needed the syscall server does them */
    uid_t u_ruid = (uid_t)args[0];
    uid_t u_euid = (uid_t)args[1];
    
    /* performing privelege test */
    bool privileged = proc_is_privileged(sys_proc_);
    
    /* performing ruid priv check */
    if(u_ruid != (uid_t)-1 &&
       !privileged)
    {
        if(u_ruid != ucred_backup.ruid && u_ruid != ucred_backup.euid)
        {
            kvo_unlock(sys_proc_);
            sys_return_failure_with_errno(EPERM);
        }
    }
    
    /* performing euid priv check */
    if(u_euid != (uid_t)-1 &&
       !privileged)
    {
        if(u_euid != ucred_backup.ruid &&
           u_euid != ucred_backup.euid &&
           u_euid != ucred_backup.svuid)
        {
            kvo_unlock(sys_proc_);
            sys_return_failure_with_errno(EPERM);
        }
    }
    
    /* setting credential */
    if(u_ruid != (uid_t)-1)
    {
        proc_setruid(sys_proc_, u_ruid);
    }
    
    /* setting credential */
    if(u_euid != (uid_t)-1)
    {
        proc_seteuid(sys_proc_, u_euid);
        if(privileged)
        {
            proc_setsvuid(sys_proc_, u_euid);
        }
    }
    
    proc_set_sugid_if_applicable(sys_proc_, ucred_backup);
    kvo_unlock(sys_proc_);
    sys_return;
}
