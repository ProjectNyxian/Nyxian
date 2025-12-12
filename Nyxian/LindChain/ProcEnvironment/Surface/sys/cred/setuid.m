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

#import <LindChain/ProcEnvironment/Surface/sys/cred/setuid.h>
#import <LindChain/ProcEnvironment/Surface/entitlement.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/Surface/proc/copy.h>

bool proc_is_privileged(ksurface_proc_copy_t *proc)
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
    /* getting args, nu checks needed the syscall server does them */
    uid_t uid = (uid_t)args[0];
    
    /* checking if process is priveleged enough */
    if(proc_is_privileged(sys_proc_copy_))
    {
        /* process is privelegedm updating credentials */
        proc_setruid(sys_proc_copy_, uid);
        proc_seteuid(sys_proc_copy_, uid);
        proc_setsvuid(sys_proc_copy_, uid);
        
        /* update and return */
        goto out_update;
    }
    else
    {
        /* setting if ruid or svuid matches the wished uid */
        if(uid == proc_getruid(sys_proc_copy_) ||
           uid == proc_getsvuid(sys_proc_copy_))
        {
            /* updating credentials */
            proc_seteuid(sys_proc_copy_, uid);
            
            /* update and return */
            goto out_update;
        }
    }
    
    /* setting errno on failure */
    sys_return_failure(EPERM);
    
out_update:
    proc_copy_update(sys_proc_copy_);
    sys_return;
}

DEFINE_SYSCALL_HANDLER(seteuid)
{
    /* getting args, nu checks needed the syscall server does them */
    uid_t euid = (uid_t)args[0];
    
    /* checking if process is priveleged enough */
    if(proc_is_privileged(sys_proc_copy_))
    {
        /* updating credentials */
        proc_seteuid(sys_proc_copy_, euid);
        
        /* update and return */
        goto out_update;
    }
    else
    {
        if(euid == proc_getruid(sys_proc_copy_) ||
           euid == proc_geteuid(sys_proc_copy_) ||
           euid == proc_getsvuid(sys_proc_copy_))
        {
            /* updating credentials */
            proc_seteuid(sys_proc_copy_, euid);
            
            /* update and return */
            goto out_update;
        }
    }
    
    /* setting errno on failure */
    sys_return_failure(EPERM);
    
out_update:
    proc_copy_update(sys_proc_copy_);
    sys_return;
}

DEFINE_SYSCALL_HANDLER(setreuid)
{
    /* getting args, nu checks needed the syscall server does them */
    uid_t ruid = (uid_t)args[0];
    uid_t euid = (uid_t)args[1];
    
    /* getting current credentials from copy */
    uid_t cur_ruid = proc_getruid(sys_proc_copy_);
    uid_t cur_euid = proc_geteuid(sys_proc_copy_);
    uid_t cur_svuid = proc_getsvuid(sys_proc_copy_);
    
    /* performing privelege test */
    bool privileged = proc_is_privileged(sys_proc_copy_);
    
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
        proc_setruid(sys_proc_copy_, ruid);
    }
    
    /* setting credential */
    if(euid != (uid_t)-1)
    {
        proc_seteuid(sys_proc_copy_, euid);
        if(privileged)
        {
            proc_setsvuid(sys_proc_copy_, euid);
        }
    }
    
    proc_copy_update(sys_proc_copy_);
    sys_return;
}
