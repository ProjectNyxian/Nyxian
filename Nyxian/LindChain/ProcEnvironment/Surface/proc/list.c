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

#include <LindChain/ProcEnvironment/Surface/proc/list.h>
#include <LindChain/ProcEnvironment/Surface/lock.h>
#include <assert.h>

proc_visibility_t get_proc_visibility(ksurface_proc_snapshot_t *caller)
{
    assert(caller != NULL);
    
    /*
     * if its a entitled process the ofc show em
     * all we got.
     */
    if(entitlement_got_entitlement(proc_getentitlements(caller), PEEntitlementProcessEnumeration))
    {
        return PROC_VIS_ALL;
    }
    
    /*
     * only show them other SID processes
     * in case it can spawn processes.
     */
    if(entitlement_got_entitlement(proc_getentitlements(caller), PEEntitlementProcessSpawn) ||
       entitlement_got_entitlement(proc_getentitlements(caller), PEEntitlementProcessSpawnSignedOnly))
    {
        return PROC_VIS_SAME_SID;
    }
    
    /*
     * nope, only them, them selves, and processes in their
     * session.
     */
    return PROC_VIS_SELF;
}

bool can_see_process(ksurface_proc_snapshot_t *caller,
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
        case PROC_VIS_SELF:
            return proc_getpid(caller) == proc_getpid(target);
        default:
            /* none is none */
            return false;
    }
}

bool is_flavour_matching(ksurface_proc_t *target,
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
        case PROC_FLV_PID:
            return dsid == proc_getpid(target);
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
    
    
    if(can_see_process(w->caller, proc, w->vis) &&
       is_flavour_matching(proc, w->flavour, w->dsid))
    {
        kinfo_proc_t *cur_kp = (kinfo_proc_t*)(((char*)w->kp) + w->len);
        memcpy(cur_kp, &(proc->bsd), sizeof(kinfo_proc_t));
        w->len += sizeof(kinfo_proc_t);
    }
    
    kvo_unlock(proc);
    kvo_release(proc);
}

ksurface_return_t proc_list(ksurface_proc_snapshot_t *proc_copy,
                            kinfo_proc_t **kp,
                            size_t *len,
                            proc_flavour_t flavour,
                            pid_t dsid)
{
    assert(proc_copy != NULL && kp != NULL && len != NULL);
    
    /*
     * allocating exactly the amount of processes structures
     * we need.
     */
    proc_list_radix_walker_t *w = malloc(sizeof(proc_list_radix_walker_t));
    
    /* sanity check */
    if(w == NULL)
    {
        return SURFACE_NOMEM;
    }
    
    /* setting up radix walker */
    w->caller = proc_copy;
    w->vis = get_proc_visibility(proc_copy);
    
    /*
     * aquire read onto proc table so we can reach a
     * safe state where we can copy the process structures
     * directly into kp.
     */
    proc_table_rdlock();
    
    w->kp = malloc(sizeof(kinfo_proc_t) * ksurface->proc_info.proc_count);
    
    if(w->kp == NULL)
    {
        proc_table_unlock();
        free(w);
        return SURFACE_NOMEM;
    }
    
    w->flavour = flavour;
    w->dsid = dsid;
    
    /*
     * now inboking the special functionality of the radix tree
     * to walk it self and execute this callback after each item.
     */
    radix_walk(&(ksurface->proc_info.tree), proc_list_radix_walker_callback, w);
    
    /* setting count and kp, to prevent memory corruption ^^ */
    *len = w->len;
    *kp = w->kp;
    free(w);
    
    /* unlocking proc table */
    proc_table_unlock();
    
    return SURFACE_SUCCESS;
}
