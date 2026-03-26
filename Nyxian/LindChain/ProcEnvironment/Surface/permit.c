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

#import <LindChain/ProcEnvironment/Surface/permit.h>
#import <LindChain/ProcEnvironment/Surface/proc/list.h>
#include <assert.h>

bool permitive_over_pid_allowed(ksurface_proc_snapshot_t *proc,
                                pid_t targetPid,
                                bool allowSessionBypass,
                                PEEntitlement entitlementsNeeded,
                                PEEntitlement targetEntitlementsNeeded)
{
    assert(proc != NULL);
    
    /*
     * getting target process, because
     * we have to check if the caller
     * process has the needed priveleges
     * to operate onto the target process
     */
    ksurface_proc_t *targetProc = NULL;
    ksurface_return_t ret = proc_for_pid(targetPid, &targetProc);
    
    if(ret != SURFACE_SUCCESS)
    {
        return false;
    }
    
    /*
     * checking if its the same process,
     * meaning the target and the caller,
     * because the caller shall have
     * permitive over it self.
     */
    if((ksurface_proc_t*)(proc->header.orig) == targetProc)
    {
        kvo_release(targetProc);
        return true;
    }
    
    proc_visibility_t vis = get_proc_visibility(proc);
    
    /* locking target process aswell */
    kvo_rdlock(targetProc);
    
    /*
     * checking if process can even see the target,
     * otherwise it shouldnt be able to have
     * permitives over a process. not seeing it means
     * it doesnt exist for the caller.
     */
    if(!can_see_process(proc, targetProc, vis))
    {
        goto out_no;
    }
    
    /*
     * checking if target process is a platformised process
     * and therefore can only be decided at by a other process
     * that is platformised
     */
    if(entitlement_got_entitlement(proc_getmaxentitlements(targetProc), PEEntitlementPlatform) &&
       !entitlement_got_entitlement(proc_getmaxentitlements(proc), PEEntitlementPlatform))
    {
        goto out_no;
    }
    
    if(allowSessionBypass &&
       proc_getsid(proc) == proc_getsid(targetProc))
    {
        goto out_euid_check;
    }
    
    /*
     * checking if target got entitlement as it
     * doesnt meet any bypassing requirements or
     * bypassing might be NO on all types.
     */
    if(targetEntitlementsNeeded != PEEntitlementNone &&
       !entitlement_got_entitlement(proc_getmaxentitlements(proc), PEEntitlementPlatform) &&
       !entitlement_got_entitlement(proc_getentitlements(targetProc), targetEntitlementsNeeded))
    {
        goto out_no;
    }
    
    if(entitlementsNeeded != PEEntitlementNone &&
       !entitlement_got_entitlement(proc_getentitlements(proc), entitlementsNeeded))
    {
        goto out_no;
    }
    
    /*
     * the final userspace check, if the process
     * got the entitlement it has to be in the
     * same UID as the target.
     */
out_euid_check:
    if(proc_geteuid(proc) != 0 &&
       proc_geteuid(proc) != proc_geteuid(targetProc))
    {
    out_no:
        kvo_unlock(targetProc);
        kvo_release(targetProc);
        return false;
    }
    
out_yes:
    kvo_unlock(targetProc);
    kvo_release(targetProc);
    return true;
}
