/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2025 - 2026 emexlab

 This file is part of Nyxian.

 Licensed under the emexLabs Public Source License, version 1.1
 (EPSL 1.1).

 Private use and modification are permitted under the license.
 Redistribution of source or binaries, modified or unmodified,
 requires prior written permission from emexLabs.

 External deployment is subject to the source-availability
 requirements and other conditions of the license.

 Provided "AS IS", without warranty, to the extent permitted by law.

 See LICENSE for the full license terms.
*/

#include <LindChain/ProcEnvironment/Surface/proc/permit.h>
#include <LindChain/ProcEnvironment/Surface/proc/list.h>
#import <LindChain/ProcEnvironment/Surface/libkern/patch.h>
#include <assert.h>
#include <errno.h>

LIBKERN_DEFINE_PATCHABLE(bool, proc_snapshot_primitive_over_proc_allowed, (ksurface_proc_snapshot_t *proc,
                                                                           ksurface_proc_t *targetProc,
                                                                           PEEntitlementFlags entitlementsNeeded,
                                                                           PEEntitlementFlags targetEntitlementsNeeded,
                                                                           errno_t *err))
{
    assert(proc != NULL);
    
    /*
     * checking if its the same process,
     * meaning the target and the caller,
     * because the caller shall have
     * permitive over it self.
     */
    if((ksurface_proc_t*)(proc->header.orig) == targetProc)
    {
        return true;
    }
    
    /*
     * checking if process can even see the target,
     * otherwise it shouldnt be able to have
     * permitives over a process. not seeing it means
     * it doesnt exist for the caller.
     */
    proc_visibility_t vis = proc_get_proc_visibility(proc);
    kvo_rdlock(targetProc);
    if(!proc_can_see_proc(proc, targetProc, vis))
    {
        *err = ESRCH;
        goto out_no;
    }
    
    /*
     * checking if target process is a platformised process
     * and therefore can only be decided at by a other process
     * that is platformised
     */
    if(entitlement_got_entitlement(proc_getmaxentitlements(targetProc), kPEEntitlementFlagPlatform) &&
       !entitlement_got_entitlement(proc_getmaxentitlements(proc), kPEEntitlementFlagPlatform) &&
       trust_enforcement_should_deny(proc_getpid(proc), kPEEntitlementFlagPlatform, "primitive over platform process"))
    {
        goto out_eperm_no;
    }
    
    if(proc_getsid(proc) == proc_getsid(targetProc) && proc->header.orig != NULL)
    {
        /*
         * check if the target is a child
         * of the parent in any way, previously
         * we checked if the process is in the
         * same session, but that would be still
         * way too generous so we close any
         * escalatory paths down, as otherwise
         * a platform process could spawn a
         * unpriveleged process and then the
         * unpriveleged process just gets the task
         * port of the parent and abuses it's
         * entitlements.
         */
        ksurface_proc_t *parent = NULL;
        proc_parent_for_proc(targetProc, &parent);
        while(parent != NULL)
        {
            if(parent == (ksurface_proc_t*)proc->header.orig)
            {
                kvo_release(parent);
                goto out_euid_check;
            }
            
            ksurface_proc_t *oldparent = parent;
            parent = NULL;
            proc_parent_for_proc(oldparent, &parent);
            kvo_release(oldparent);
        }
    }
    
    /*
     * checking if target got entitlement as it
     * doesnt meet any bypassing requirements or
     * bypassing might be NO on all types.
     */
    if(targetEntitlementsNeeded != kPEEntitlementFlagNone &&
       !entitlement_got_entitlement(proc_getmaxentitlements(proc), kPEEntitlementFlagPlatform) &&
       !entitlement_got_entitlement(proc_getentitlements(targetProc), targetEntitlementsNeeded) &&
       trust_enforcement_should_deny(proc_getpid(targetProc), targetEntitlementsNeeded & ~proc_getentitlements(targetProc), "primitive target requirement"))
    {
        goto out_eperm_no;
    }
    
    if(entitlementsNeeded != kPEEntitlementFlagNone &&
       !entitlement_got_entitlement(proc_getentitlements(proc), entitlementsNeeded) &&
       trust_enforcement_should_deny(proc_getpid(proc), entitlementsNeeded & ~proc_getentitlements(proc), "primitive over process"))
    {
        goto out_eperm_no;
    }
    
    /*
     * the final userspace check, if the process
     * got the entitlement it has to be in the
     * same UID as the target.
     */
out_euid_check:
    if(proc_geteuid(proc) != 0 &&
       (proc_did_change_credentials(targetProc) || proc_geteuid(proc) != proc_geteuid(targetProc)))
    {
    out_eperm_no:
        *err = EPERM;
    out_no:
        kvo_unlock(targetProc);
        return false;
    }
    
out_yes:
    kvo_unlock(targetProc);
    return true;
}

bool proc_primitive_over_proc_allowed(ksurface_proc_t *proc,
                                      ksurface_proc_t *targetProc,
                                      PEEntitlementFlags entitlementsNeeded,
                                      PEEntitlementFlags targetEntitlementsNeeded,
                                      errno_t *err)
{
    kvo_rdlock(proc);   /* when rdlocking a non snapshot it shall be like a snapshot */
    bool isAllowed = proc_snapshot_primitive_over_proc_allowed((ksurface_proc_snapshot_t*)proc, targetProc, entitlementsNeeded, targetEntitlementsNeeded, err);
    kvo_unlock(proc);
    return isAllowed;
}

bool proc_pid_primitive_over_pid_allowed(pid_t pid,
                                         pid_t targetPid,
                                         PEEntitlementFlags entitlementsNeeded,
                                         PEEntitlementFlags targetEntitlementsNeeded,
                                         errno_t *err)
{
    /* look both up */
    ksurface_proc_t *proc = NULL;
    if(proc_for_pid(pid, &proc) != KERN_SUCCESS)
    {
        *err = ESRCH;
        return false;
    }
    
    ksurface_proc_t *targetProc = NULL;
    if(proc_for_pid(targetPid, &targetProc) != KERN_SUCCESS)
    {
        kvo_release(proc);
        *err = ESRCH;
        return false;
    }
    
    bool isAllowed = proc_primitive_over_proc_allowed(proc, targetProc, entitlementsNeeded, targetEntitlementsNeeded, err);
    kvo_release(targetProc);
    kvo_release(proc);
    return isAllowed;
}
