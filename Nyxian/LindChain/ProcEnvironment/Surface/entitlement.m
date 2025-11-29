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

#import <LindChain/ProcEnvironment/Surface/entitlement.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>

bool proc_got_entitlement(pid_t pid,
                          PEEntitlement entitlement)
{
    // TODO: Check if proc exists
    // Get proc
    ksurface_proc_t *proc = proc_for_pid(pid);
    if(proc == NULL)
    {
        proc_release(proc);
        // If it was not successful then we return false, basically denying every entitlement no matter what
        return false;
    }
    
    PEEntitlement procEntitlements = proc_getentitlements(proc);
    proc_release(proc);
    
    // Now check entitlements
    return(procEntitlements & entitlement) == entitlement;
}

bool entitlement_got_entitlement(PEEntitlement present,
                                 PEEntitlement needed)
{
    // Check entitlements
    return(present & needed) == needed;
}
