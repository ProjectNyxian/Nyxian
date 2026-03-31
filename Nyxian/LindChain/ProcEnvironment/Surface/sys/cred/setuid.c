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

#include <LindChain/ProcEnvironment/Surface/sys/cred/setuid.h>
#include <LindChain/ProcEnvironment/Surface/entitlement.h>
#include <LindChain/ProcEnvironment/Surface/proc/proc.h>

bool proc_is_privileged(ksurface_proc_t *proc)
{
    /* Checking if process is entitled to elevate. */
    if(entitlement_got_entitlement(proc_getentitlements(proc), PEEntitlementProcessElevate))
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
    
    /* getting args, nu checks needed the syscall server does them */
    uid_t uid = (uid_t)args[0];
    
    /* checking if process is priveleged enough */
    if(proc_is_privileged(sys_proc_))
    {
        /* process is privelegedm updating credentials */
        proc_setruid(sys_proc_, uid);
        proc_seteuid(sys_proc_, uid);
        proc_setsvuid(sys_proc_, uid);
        
        /* update and return */
        goto out_update;
    }
    else
    {
        /* setting if ruid or svuid matches the wished uid */
        if(uid == proc_getruid(sys_proc_) ||
           uid == proc_getsvuid(sys_proc_))
        {
            /* updating credentials */
            proc_seteuid(sys_proc_, uid);
            
            /* update and return */
            goto out_update;
        }
    }
    
    /* setting errno on failure */
    kvo_unlock(sys_proc_);
    sys_return_failure(EPERM);
    
out_update:
    sys_proc_->bsd.kp_proc.p_flag |= P_SUGID;
    kvo_unlock(sys_proc_);
    sys_return;
}

DEFINE_SYSCALL_HANDLER(seteuid)
{
    /* syscall wrapper */
    kvo_wrlock(sys_proc_);
    
    /* getting args, nu checks needed the syscall server does them */
    uid_t euid = (uid_t)args[0];
    
    /* checking if process is priveleged enough */
    if(proc_is_privileged(sys_proc_))
    {
        /* updating credentials */
        proc_seteuid(sys_proc_, euid);
        
        /* update and return */
        goto out_update;
    }
    else
    {
        if(euid == proc_getruid(sys_proc_) ||
           euid == proc_geteuid(sys_proc_) ||
           euid == proc_getsvuid(sys_proc_))
        {
            /* updating credentials */
            proc_seteuid(sys_proc_, euid);
            
            /* update and return */
            goto out_update;
        }
    }
    
    /* setting errno on failure */
    kvo_unlock(sys_proc_);
    sys_return_failure(EPERM);
    
out_update:
    sys_proc_->bsd.kp_proc.p_flag |= P_SUGID;
    kvo_unlock(sys_proc_);
    sys_return;
}

DEFINE_SYSCALL_HANDLER(setreuid)
{
    /* syscall wrapper */
    kvo_wrlock(sys_proc_);
    
    /* getting args, nu checks needed the syscall server does them */
    uid_t ruid = (uid_t)args[0];
    uid_t euid = (uid_t)args[1];
    
    /* getting current credentials from copy */
    uid_t cur_ruid = proc_getruid(sys_proc_);
    uid_t cur_euid = proc_geteuid(sys_proc_);
    uid_t cur_svuid = proc_getsvuid(sys_proc_);
    
    /* performing privelege test */
    bool privileged = proc_is_privileged(sys_proc_);
    
    /* performing ruid priv check */
    if(ruid != (uid_t)-1 &&
       !privileged)
    {
        if(ruid != cur_ruid && ruid != cur_euid)
        {
            sys_return_failure(EPERM);
        }
    }
    
    /* performing euid priv check */
    if(euid != (uid_t)-1 &&
       !privileged)
    {
        if(euid != cur_ruid &&
           euid != cur_euid &&
           euid != cur_svuid)
        {
            sys_return_failure(EPERM);
        }
    }
    
    /* setting credential */
    if(ruid != (uid_t)-1)
    {
        proc_setruid(sys_proc_, ruid);
    }
    
    /* setting credential */
    if(euid != (uid_t)-1)
    {
        proc_seteuid(sys_proc_, euid);
        if(privileged)
        {
            proc_setsvuid(sys_proc_, euid);
        }
    }
    
    sys_proc_->bsd.kp_proc.p_flag |= P_SUGID;
    kvo_unlock(sys_proc_);
    sys_return;
}
