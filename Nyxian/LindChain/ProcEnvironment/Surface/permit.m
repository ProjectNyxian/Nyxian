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

BOOL permitive_over_process_allowed(pid_t callerPid,
                                    pid_t targetPid)
{
    // Only let host proceed
    environment_must_be_role(EnvironmentRoleHost);
    
    // Get the objects of both pids
    ksurface_proc_t *callerProc = proc_for_pid(callerPid);
    if(callerProc == NULL)
    {
        return NO;
    }
    
    ksurface_proc_t *targetProc = proc_for_pid(targetPid);
    if(targetProc == NULL)
    {
        proc_release(callerProc);
        return NO;
    }
    
    // Gets creds
    uid_t caller_uid = proc_getuid(callerProc);
    
    // Platform check
    if(entitlement_got_entitlement(proc_getentitlements(targetProc), PEEntitlementPlatform) &&
       !entitlement_got_entitlement(proc_getentitlements(callerProc), PEEntitlementPlatform))
    {
        // If the target got platform but the caller doesnt it gets denied
        proc_release(callerProc);
        proc_release(targetProc);
        return NO;
    }
    
    // Gets if its allowed in the first place
    if((caller_uid == 0) ||
       (caller_uid == proc_getuid(targetProc)) ||
       (caller_uid == proc_getruid(targetProc)))
    {
        proc_release(callerProc);
        proc_release(targetProc);
        return YES;
    }
    
    return NO;
}
