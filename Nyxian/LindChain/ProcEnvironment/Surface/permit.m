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

BOOL permitive_over_process_allowed(ksurface_proc_t *proc,
                                    pid_t targetPid)
{
    // Only let host proceed
    environment_must_be_role(EnvironmentRoleHost);
    
    // Get target process
    ksurface_proc_t *targetProc = proc_for_pid(targetPid);
    if(targetProc == NULL)
    {
        return NO;
    }
    
    // Locking processes
    proc_read_lock(proc);
    proc_read_lock(targetProc);
    
    // Gets creds
    uid_t caller_uid = proc_getuid(proc);
    
    // Root check
    if(caller_uid == 0)
    {
        proc_unlock(targetProc);
        proc_release(targetProc);
        proc_unlock(proc);
        return YES;
    }
    
    // Platform check
    if(entitlement_got_entitlement(proc_getentitlements(targetProc), PEEntitlementPlatform) &&
       !entitlement_got_entitlement(proc_getentitlements(proc), PEEntitlementPlatform))
    {
        // If the target got platform but the caller doesnt it gets denied
        proc_unlock(targetProc);
        proc_release(targetProc);
        proc_unlock(proc);
        return NO;
    }
    
    // Gets if its allowed in the first place
    if((caller_uid == proc_getuid(targetProc)) ||
       (caller_uid == proc_getruid(targetProc)))
    {
        proc_unlock(targetProc);
        proc_release(targetProc);
        proc_unlock(proc);
        return YES;
    }
    
    // Unlocking processes locks
    proc_unlock(targetProc);
    proc_release(targetProc);
    proc_unlock(proc);
    return NO;
}
