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

#import <LindChain/ProcEnvironment/Surface/proc/userapi/copylist.h>
#import <LindChain/ProcEnvironment/Surface/proc/rw.h>

proc_visibility_t get_proc_visibility(ksurface_proc_t *caller)
{
    if(caller == NULL) return PROC_VIS_NONE;
    uid_t uid = proc_getruid(caller);
    if(uid == 0) return PROC_VIS_ALL;
    if(entitlement_got_entitlement(proc_getentitlements(caller), PEEntitlementProcessEnumeration)) return PROC_VIS_ALL;
    return PROC_VIS_SAME_UID;
}

bool can_see_process(ksurface_proc_t *caller,
                     ksurface_proc_t *target,
                     proc_visibility_t vis)
{
    switch (vis) {
        case PROC_VIS_ALL:
            return true;
        case PROC_VIS_SAME_UID:
            return proc_getruid(caller) == proc_getruid(target);
        case PROC_VIS_SELF:
            return proc_getpid(caller) == proc_getpid(target);
        case PROC_VIS_NONE:
        default:
            return false;
    }
}

uint64_t _get_time_ms(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000ULL + ts.tv_nsec / 1000000ULL;
}

void copy_proc_to_user(ksurface_proc_t *proc,
                       kinfo_proc_t *kp)
{
    memcpy(kp, &(proc->kproc.kcproc.bsd), sizeof(kinfo_proc_t));
}

// typedef void (*radix_walk_fn)(pid_t pid, void *value, void *ctx);
void proc_snapshot_create_radix_walk(pid_t pid,
                                     void *value,
                                     void *ctx)
{
    /* getting ctx back */
    proc_snapshot_radix_ctx *rctx = ctx;
    ksurface_proc_t *proc = value;
    
    /* trying to retain process */
    if(!proc_retain(proc))
    {
        /* continue */
        return;
    }
    
    /* lock read */
    proc_read_lock(proc);
    
    if(can_see_process(rctx->caller, proc, rctx->vis))
    {
        copy_proc_to_user(proc, &(rctx->snap.kp[rctx->snap.count++]));
    }
    
    /* unlock */
    proc_unlock(proc);
    proc_release(proc);
}

proc_list_err_t proc_snapshot_create(ksurface_proc_t *proc,
                                     proc_snapshot_t **snapshot_out)
{    
    /* null pointer check */
    if(snapshot_out == NULL)
    {
        return PROC_LIST_ERR_NULL;
    }
    
    /* setting it to null */
    *snapshot_out = NULL;
    
    /* checking if proc is null*/
    if(proc == NULL)
    {
        return PROC_LIST_ERR_PERM;
    }
    
    /* allocate context */
    proc_snapshot_radix_ctx *ctx = malloc(sizeof(proc_snapshot_radix_ctx) + (PROC_MAX * sizeof(kinfo_proc_t)));
    if(ctx == NULL)
    {
        return PROC_LIST_ERR_NO_SPACE;
    }
    
    /* setting up snapshot */
    ctx->caller = proc;
    ctx->snap.count = 0;
    ctx->snap.timestamp = _get_time_ms();
    ctx->vis = get_proc_visibility(proc);
    
    /* invoke read */
    proc_table_read_lock();
    
    /* invoke walk */
    radix_walk(&(ksurface->proc_info.tree), proc_snapshot_create_radix_walk, ctx);
    
    /* unlocking proc table */
    proc_table_unlock();
    
    proc_snapshot_t *snap = malloc(sizeof(proc_snapshot_t) + (PROC_MAX * sizeof(kinfo_proc_t)));
    memcpy(snap, &(ctx->snap), sizeof(proc_snapshot_t) + (PROC_MAX * sizeof(kinfo_proc_t)));
    *snapshot_out = snap;
    free(ctx);
    
    return PROC_LIST_OK;
}

void proc_snapshot_free(proc_snapshot_t *snap)
{
    free(snap);
}

bool proc_nyx_copy(ksurface_proc_t *proc,
                   pid_t targetPid,
                   knyx_proc_t *nyx)
{
    /* getting visibility */
    proc_visibility_t vis = get_proc_visibility(proc);
    if(vis == PROC_VIS_NONE)
    {
        return false;
    }
    
    /* getting process of targetpid */
    ksurface_proc_t *targetProc = proc_for_pid(targetPid);
    if(targetProc != NULL)
    {
        if(can_see_process(proc, targetProc, vis))
        {
            proc_read_lock(targetProc);
            *nyx = targetProc->kproc.kcproc.nyx;
            proc_unlock(targetProc);
            
            /* releasing process */
            proc_release(targetProc);
            return true;
        }
        /* releasing process */
        proc_release(targetProc);
    }
    return false;
}
