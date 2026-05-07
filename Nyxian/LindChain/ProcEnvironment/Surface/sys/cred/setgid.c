/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 mach-port-t

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

#include <LindChain/ProcEnvironment/Surface/sys/cred/setgid.h>
#include <LindChain/ProcEnvironment/Surface/entitlement.h>
#include <LindChain/ProcEnvironment/Surface/proc/proc.h>

extern bool proc_is_privileged(ksurface_proc_t *proc);

DEFINE_SYSCALL_HANDLER(setgid)
{
    /* getting arguments */
    gid_t gid = (gid_t)args[0];
    
    kvo_wrlock(sys_proc_);
    
    /* checking privelege */
    if(proc_is_privileged(sys_proc_))
    {
        /* updating credentials */
        proc_setrgid(sys_proc_, gid);
        proc_setegid(sys_proc_, gid);
        proc_setsvgid(sys_proc_, gid);
        
        /* update and return */
        goto out_update;
    }
    else
    {
        if(gid == proc_getrgid(sys_proc_) ||
           gid == proc_getsvgid(sys_proc_))
        {
            /* updating credentials */
            proc_setegid(sys_proc_, gid);
            
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

DEFINE_SYSCALL_HANDLER(setegid)
{
    /* getting arguments */
    gid_t egid = (gid_t)args[0];
    
    kvo_wrlock(sys_proc_);
    
    /* checking privelege */
    if(proc_is_privileged(sys_proc_))
    {
        /* updating credentials */
        proc_setegid(sys_proc_, egid);
        
        /* update and return */
        goto out_update;
    }
    else
    {
        if(egid == proc_getrgid(sys_proc_) ||
           egid == proc_getegid(sys_proc_) ||
           egid == proc_getsvgid(sys_proc_))
        {
            /* updating credentials */
            proc_setegid(sys_proc_, egid);
            
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

DEFINE_SYSCALL_HANDLER(setregid)
{
    kvo_wrlock(sys_proc_);
    
    /* getting arguments */
    gid_t rgid = (gid_t)args[0];
    gid_t egid = (gid_t)args[1];
    
    /* getting current credentials */
    gid_t cur_rgid = proc_getrgid(sys_proc_);
    gid_t cur_egid = proc_getegid(sys_proc_);
    gid_t cur_svgid = proc_getsvgid(sys_proc_);
    
    /* getting privele status of the process */
    bool privileged = proc_is_privileged(sys_proc_);
    
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
        proc_setrgid(sys_proc_, rgid);
    }
    
    /* setting credential */
    if(egid != (gid_t)-1)
    {
        proc_setegid(sys_proc_, egid);
        if(privileged)
        {
            proc_setsvgid(sys_proc_, egid);
        }
    }
    
    sys_proc_->bsd.kp_proc.p_flag |= P_SUGID;
    kvo_unlock(sys_proc_);
    sys_return;
}
