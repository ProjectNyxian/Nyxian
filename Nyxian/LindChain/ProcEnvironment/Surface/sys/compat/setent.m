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

#import <LindChain/ProcEnvironment/Surface/sys/compat/setent.h>
#import <LindChain/ProcEnvironment/Surface/proc/copy.h>

DEFINE_SYSCALL_HANDLER(setent)
{
    sys_name("SYS_setent");
    
    /* MARK: THIS IS USER SUPPLIED */
    PEEntitlement userPassed = (PEEntitlement)args[0];
    
    /* getting the added mask out of both entitlements */
    PEEntitlement added = (~proc_getentitlements(sys_proc_copy_)) & userPassed;
    
    /*
     * only platform process entitlement
     * can add entitlements of it self,
     * and not all.
     */
    if(added != PEEntitlementNone &&
       !entitlement_got_entitlement(proc_getentitlements(sys_proc_copy_), PEEntitlementPlatform))
    {
        sys_return_failure(EPERM);
    }
    
    /* deny setting certain entitlements */
    if(added & (PEEntitlementPlatform | PEEntitlementProcessElevate | PEEntitlementTaskForPid |
                PEEntitlementTrustCacheWrite))
    {
        sys_return_failure(EPERM);
    }
    
    proc_setentitlements(sys_proc_copy_, userPassed);
    proc_copy_update(sys_proc_copy_);
    
    sys_return;
}
