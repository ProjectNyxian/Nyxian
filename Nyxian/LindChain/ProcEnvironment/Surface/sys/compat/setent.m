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

#import <LindChain/ProcEnvironment/Surface/sys/compat/setent.h>

DEFINE_SYSCALL_HANDLER(setent)
{
    kvo_wrlock(sys_proc_);
    
    /* MARK: THIS IS USER SUPPLIED */
    PEEntitlement userPassed = (PEEntitlement)args[0];
    
    /* getting the added mask out of entitlements */
    PEEntitlement added = (~proc_getentitlements(sys_proc_)) & userPassed;
    
    /* deny adding entitlements not present in max entitlements */
    if(!entitlement_got_entitlement(proc_getmaxentitlements(sys_proc_), added))
    {
        kvo_unlock(sys_proc_);
        sys_return_failure(EPERM);
    }
    
    proc_setentitlements(sys_proc_, userPassed);
    
    kvo_unlock(sys_proc_);
    sys_return;
}
