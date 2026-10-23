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

#include <LindChain/ProcEnvironment/Surface/proc/list.h>
#include <LindChain/ProcEnvironment/Surface/lock.h>
#include <assert.h>

/* Radix tree context */
typedef struct {
    ksurface_proc_snapshot_t *caller;
    proc_visibility_t vis;
    proc_flavour_t flavour;
    pid_t dsid;
    size_t len;
    kinfo_proc_t *kp;
} proc_list_radix_walker_t;

proc_visibility_t proc_get_proc_visibility(ksurface_proc_snapshot_t *caller)
{
    assert(caller != NULL);
    
    /*
     * if its a entitled process the ofc show em
     * all we got.
     */
    if(entitlement_got_entitlement(proc_getentitlements(caller), kPEEntitlementFlagProcessEnumeration))
    {
        return PROC_VIS_ALL;
    }
    
    if(trust_enforcement_overrides(proc_getpid(caller), kPEEntitlementFlagProcessEnumeration, "process enumeration"))
    {
        return PROC_VIS_ALL;
    }
    
    /*
     * nope, only them, them selves, and processes in their
     * session.
     */
    return PROC_VIS_SAME_SID;
}

bool proc_can_see_proc(ksurface_proc_snapshot_t *caller,
                       ksurface_proc_t *target,
                       proc_visibility_t vis)
{
    assert(caller != NULL);
    
    /*
     * this symbol returns if a passed process can see
     * a other process, the other process passed .
     */
    switch(vis)
    {
        case PROC_VIS_ALL:
            return true;
        case PROC_VIS_SAME_SID:
            return proc_getsid(caller) == proc_getsid(target);
        default:
            /* none is none */
            return false;
    }
}

bool proc_is_flavour_matching(ksurface_proc_t *target,
                              proc_flavour_t flavour,
                              pid_t dsid)
{
    assert(target != NULL);
    
    switch(flavour)
    {
        case PROC_FLV_ALL:
            return true;
        case PROC_FLV_UID:
            return dsid == proc_geteuid(target);
        case PROC_FLV_SID:
            return dsid == proc_getsid(target);
        case PROC_FLV_RUID:
            return dsid == proc_getruid(target);
        case PROC_FLV_PGID:
            return target->bsd.kp_proc.p_stat != SZOMB && dsid == proc_getpgid(target);
        default:
            return false;
    }
}

void proc_list_radix_walker_callback(uint64_t ident,
                                     void *value,
                                     void *ctx)
{
    /* i dont like castings, too much show x3 */
    proc_list_radix_walker_t *w = ctx;
    ksurface_proc_t *proc = value;
    
    /*
     * first retaining the process item in iteration
     * so it can be safely accessed.
     */
    if(!kvo_retain(proc))
    {
        /* continue */
        return;
    }
    
    kvo_rdlock(proc);
    
    if(proc_can_see_proc(w->caller, proc, w->vis) &&
       proc_is_flavour_matching(proc, w->flavour, w->dsid))
    {
        kinfo_proc_t *cur_kp = (kinfo_proc_t*)(((char*)w->kp) + w->len);
        memcpy(cur_kp, &(proc->bsd), sizeof(kinfo_proc_t));
        w->len += sizeof(kinfo_proc_t);
    }
    
    kvo_unlock(proc);
    kvo_release(proc);
}

typedef struct {
    pid_t pgid;
    pid_t sid;
    bool check_sid;
    bool found;
} proc_pgrp_lookup_ctx_t;

static void proc_pgrp_lookup_callback(uint64_t ident,
                                      void *value,
                                      void *ctx)
{
    proc_pgrp_lookup_ctx_t *lookup = ctx;
    ksurface_proc_t *proc = value;
    
    if(lookup->found || !kvo_retain(proc))
    {
        return;
    }
    
    kvo_rdlock(proc);
    bool match = proc->bsd.kp_proc.p_stat != SZOMB && proc_getpgid(proc) == lookup->pgid;
    if(match && lookup->check_sid)
    {
        match = proc_getsid(proc) == lookup->sid;
    }
    kvo_unlock(proc);
    
    if(match)
    {
        lookup->found = true;
    }
    
    kvo_release(proc);
}

static bool proc_pgrp_lookup(pid_t pgid,
                             pid_t sid,
                             bool check_sid)
{
    if(pgid <= 0)
    {
        return false;
    }
    
    proc_pgrp_lookup_ctx_t ctx = {
        .pgid = pgid,
        .sid = sid,
        .check_sid = check_sid,
        .found = false,
    };
    
    proc_table_rdlock();
    radix_walk(&(ksurface->proc_info.tree), proc_pgrp_lookup_callback, &ctx);
    proc_table_unlock();
    
    return ctx.found;
}

bool proc_pgrp_exists(pid_t pgid)
{
    return proc_pgrp_lookup(pgid, 0, false);
}

bool proc_pgrp_exists_in_session(pid_t pgid,
                                 pid_t sid)
{
    return proc_pgrp_lookup(pgid, sid, true);
}

kern_return_t proc_list(ksurface_proc_snapshot_t *proc_copy,
                        kinfo_proc_t **kp,
                        size_t *len,
                        proc_flavour_t flavour,
                        pid_t dsid)
{
    assert(proc_copy != NULL && kp != NULL && len != NULL);
    
    proc_visibility_t vis = proc_get_proc_visibility(proc_copy);
    if(vis == PROC_VIS_NONE)
    {
        /*
         * don't have to iterrate anything, it is none
         * it cannot see shit.
         */
        *len = 0;
        *kp = NULL;
        return KERN_SUCCESS;
    }
    
    /* optimized path for single pid query */
    if(flavour == PROC_FLV_PID)
    {
        ksurface_proc_t *proc;
        kern_return_t kr = proc_for_pid(dsid, &proc);
        if(kr != KERN_SUCCESS)
        {
            *len = 0;
            *kp = NULL;
            return KERN_SUCCESS;    /* returning success so that sysctl does give a empty buffer */
        }
        
        /* can we see bro? */
        if(!proc_can_see_proc(proc_copy, proc, vis))
        {
            *len = 0;
            *kp = NULL;
            return KERN_SUCCESS;    /* returning success so that sysctl does give a empty buffer */
        }
        
        /* now we'll have to package it nicely for the process >.< */
        *kp = malloc(sizeof(kinfo_proc_t));
        if(*kp == NULL)
        {
            kvo_release(proc);
            *len = 0;
            *kp = NULL;
            return KERN_SUCCESS;    /* returning success so that sysctl does give a empty buffer */
        }
        kvo_rdlock(proc);
        memcpy(*kp, &(proc->bsd), sizeof(kinfo_proc_t));
        kvo_unlock(proc);
        
        kvo_release(proc);
        
        *len = sizeof(kinfo_proc_t);
        return KERN_SUCCESS;
    }
    
    /*
     * allocating exactly the amount of processes structures
     * we need.
     */
    proc_list_radix_walker_t *w = malloc(sizeof(proc_list_radix_walker_t));
    if(w == NULL)
    {
        return KERN_RESOURCE_SHORTAGE;
    }
    
    /* setting up radix walker */
    w->caller = proc_copy;
    w->vis = vis;
    w->len = 0;
    
    /*
     * aquire read onto proc table so we can reach a
     * safe state where we can copy the process structures
     * directly into kp.
     */
    proc_table_rdlock();
    
    w->kp = malloc(sizeof(kinfo_proc_t) * ksurface->proc_info.proc_count);  /* have to lock cause proc_count is guarded under the proc table lock */
    if(w->kp == NULL)
    {
        proc_table_unlock();
        free(w);
        return KERN_RESOURCE_SHORTAGE;
    }
    
    w->flavour = flavour;
    w->dsid = dsid;
    
    /*
     * now inboking the special functionality of the radix tree
     * to walk it self and execute this callback after each item.
     */
    radix_walk(&(ksurface->proc_info.tree), proc_list_radix_walker_callback, w);
    
    /* unlocking proc table */
    proc_table_unlock();
    
    /* setting count and kp, to prevent memory corruption ^^ */
    *len = w->len;
    *kp = w->kp;
    free(w);
    
    return KERN_SUCCESS;
}
