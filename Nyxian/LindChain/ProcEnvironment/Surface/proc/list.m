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

#import <LindChain/ProcEnvironment/Surface/proc/list.h>

proc_visibility_t get_proc_visibility(ksurface_proc_copy_t *caller)
{
    /* something went wrong here, dont let anyone see ^^ */
    if(caller == NULL)
    {
        return PROC_VIS_NONE;
    }
    
    /*
     * if its root or a entitled process the ofc show em
     * all we got.
     */
    uid_t uid = proc_getruid(caller);
    if(uid == 0 || entitlement_got_entitlement(proc_getentitlements(caller), PEEntitlementProcessEnumeration))
    {
        return PROC_VIS_ALL;
    }
    
    /*
     * nope, only them, them selves, and processes in their
     * session.
     */
    return PROC_VIS_SAME_SID;
}

bool can_see_process(ksurface_proc_copy_t *caller,
                     ksurface_proc_t *target,
                     proc_visibility_t vis)
{
    /*
     * this symbol returns if a passed process can see
     * a other process, the other process passed .
     */
    switch(vis)
    {
        case PROC_VIS_ALL:
            return true;
        case PROC_VIS_SAME_UID:
            return proc_getruid(caller) == proc_getruid(target) || proc_getsid(caller) == proc_getsid(target);
        case PROC_VIS_SAME_SID:
            return proc_getpid(caller) == proc_getpid(target) || proc_getsid(caller) == proc_getsid(target);
        default:
            /* none is none */
            return false;
    }
}

void copy_proc_to_user(ksurface_proc_t *proc,
                       kinfo_proc_t *kp)
{
    memcpy(kp, &(proc->kproc.kcproc.bsd), sizeof(kinfo_proc_t));
}

void proc_list_radix_walker_callback(pid_t pid,
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
    
    
    if(can_see_process(w->caller, proc, w->vis))
    {
        copy_proc_to_user(proc, &(w->kp[w->count++]));
    }
    
    kvo_unlock(proc);
    kvo_release(proc);
}

ksurface_return_t proc_list(ksurface_proc_copy_t *proc_copy,
                            kinfo_proc_t **kp,
                            uint32_t *count)
{
    /* sanity check */
    if(proc_copy == NULL ||
       kp == NULL ||
       count == NULL)
    {
        return SURFACE_NULLPTR;
    }
    
    /*
     * aquire read onto proc table so we can reach a
     * safe state where we can copy the process structures
     * directly into kp.
     */
    pthread_rwlock_rdlock(&(ksurface->proc_info.struct_lock));
    
    /*
     * allocating exactly the amount of processes structures
     * we need.
     */
    proc_list_radix_walker_t *w = malloc(sizeof(proc_list_radix_walker_t));
    
    /* sanity check */
    if(w == NULL)
    {
        pthread_rwlock_unlock(&(ksurface->proc_info.struct_lock));
        return SURFACE_NOMEM;
    }
    
    /* setting up radix walker */
    w->caller = proc_copy;
    w->vis = get_proc_visibility(proc_copy);
    w->kp = malloc(sizeof(kinfo_proc_t) * ksurface->proc_info.proc_count);
    w->count = 0;
    
    /*
     * now inboking the special functionality of the radix tree
     * to walk it self and execute this callback after each item.
     */
    radix_walk(&(ksurface->proc_info.tree), proc_list_radix_walker_callback, w);
    
    /* setting count and kp, to prevent memory corruption ^^ */
    *count = w->count;
    *kp = w->kp;
    free(w);
    
    /* unlocking proc table */
    pthread_rwlock_unlock(&(ksurface->proc_info.struct_lock));
    
    return SURFACE_SUCCESS;
}
