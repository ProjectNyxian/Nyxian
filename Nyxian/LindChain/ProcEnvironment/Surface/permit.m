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

#import <LindChain/ProcEnvironment/environment.h>
#import <LindChain/ProcEnvironment/Surface/permit.h>
#import <LindChain/ProcEnvironment/Surface/proc/rw.h>
#import <LindChain/ProcEnvironment/Surface/proc/list.h>

BOOL permitive_over_pid_allowed(ksurface_proc_copy_t *proc,
                                pid_t targetPid)
{
    /* null pointer check */
    if(proc == NULL)
    {
        return NO;
    }
    
    /* getting uid */
    uid_t caller_uid = proc_getruid(proc);
    pid_t caller_sid = proc_getsid(proc);
    
    /* if proc is root its automatically allowed */
    if(caller_uid == 0)
    {
        return YES;
    }
    
    /* getting target process */
    ksurface_proc_t *targetProc = proc_for_pid(targetPid);
    if(targetProc == NULL)
    {
        return NO;
    }
    
    BOOL allowed = NO;
    
    /* checking if proc is targetProc */
    if(proc->proc == targetProc)
    {
        allowed = YES;
        goto out_release_target;
    }
    
    /* locking target process aswell */
    KVOBJECT_RDLOCK(targetProc);
    
    /* checking if target process is a platformised process and therefore can only be decided at by a other process that is platformised */
    if(entitlement_got_entitlement(proc_getentitlements(targetProc), PEEntitlementPlatform) &&
       !entitlement_got_entitlement(proc_getentitlements(proc), PEEntitlementPlatform))
    {
        /* nope! */
        goto out_unlock;
    }
    
    /* getting visibility */
    proc_visibility_t vis = get_proc_visibility(proc);
    
    /* checking if process can even see the target */
    if(!can_see_process(proc, targetProc, vis))
    {
        /* also nope! */
        goto out_unlock;
    }
    
    /* checking if the process is allowed to gain permitives naturally over the target */
    if(caller_uid == proc_getruid(targetProc) ||
       caller_sid == proc_getsid(targetProc))
    {
        allowed = YES;
    }
    
out_unlock:
    KVOBJECT_UNLOCK(targetProc);
out_release_target:
    KVOBJECT_RELEASE(targetProc);
    return allowed;
}
