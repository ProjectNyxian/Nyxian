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

#import <LindChain/ProcEnvironment/Surface/sys/cred/setgid.h>
#import <LindChain/ProcEnvironment/Surface/entitlement.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/Surface/proc/copy.h>

extern bool proc_is_privileged(ksurface_proc_copy_t *proc);

DEFINE_SYSCALL_HANDLER(setgid)
{
    /* syscall wrapper */
    sys_name("SYS_setgid");
    
    /* getting arguments */
    gid_t gid = (gid_t)args[0];
    
    /* checking privelege */
    if(proc_is_privileged(sys_proc_copy_))
    {
        /* updating credentials */
        proc_setrgid(sys_proc_copy_, gid);
        proc_setegid(sys_proc_copy_, gid);
        proc_setsvgid(sys_proc_copy_, gid);
        
        /* update and return */
        goto out_update;
    }
    else
    {
        if(gid == proc_getrgid(sys_proc_copy_) ||
           gid == proc_getsvgid(sys_proc_copy_))
        {
            /* updating credentials */
            proc_setegid(sys_proc_copy_, gid);
            
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

DEFINE_SYSCALL_HANDLER(setegid)
{
    /* syscall wrapper */
    sys_name("SYS_setegid");
    
    /* getting arguments */
    gid_t egid = (gid_t)args[0];
    
    /* checking privelege */
    if(proc_is_privileged(sys_proc_copy_))
    {
        /* updating credentials */
        proc_setegid(sys_proc_copy_, egid);
        
        /* update and return */
        goto out_update;
    }
    else
    {
        if(egid == proc_getrgid(sys_proc_copy_) ||
           egid == proc_getegid(sys_proc_copy_) ||
           egid == proc_getsvgid(sys_proc_copy_))
        {
            /* updating credentials */
            proc_setegid(sys_proc_copy_, egid);
            
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

DEFINE_SYSCALL_HANDLER(setregid)
{
    /* syscall wrapper */
    sys_name("SYS_setregid");
    
    /* getting arguments */
    gid_t rgid = (gid_t)args[0];
    gid_t egid = (gid_t)args[1];
    
    /* getting current credentials */
    gid_t cur_rgid = proc_getrgid(sys_proc_copy_);
    gid_t cur_egid = proc_getegid(sys_proc_copy_);
    gid_t cur_svgid = proc_getsvgid(sys_proc_copy_);
    
    /* getting privele status of the process */
    bool privileged = proc_is_privileged(sys_proc_copy_);
    
    /* performing rgid priv check */
    if(rgid != (gid_t)-1 &&
       !privileged)
    {
        if(rgid != cur_rgid &&
           rgid != cur_egid)
        {
            sys_return_failure(EPERM);
        }
    }
    
    /* performing egid priv check */
    if(egid != (gid_t)-1 &&
       !privileged)
    {
        if(egid != cur_rgid &&
           egid != cur_egid && egid != cur_svgid)
        {
            sys_return_failure(EPERM);
        }
    }
    
    /* setting credential */
    if(rgid != (gid_t)-1)
    {
        proc_setrgid(sys_proc_copy_, rgid);
    }
    
    /* setting credential */
    if(egid != (gid_t)-1)
    {
        proc_setegid(sys_proc_copy_, egid);
        if(privileged)
        {
            proc_setsvgid(sys_proc_copy_, egid);
        }
    }
    
    proc_copy_update(sys_proc_copy_);
    sys_return;
}
