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

proc_visibility_t get_proc_visibility(ksurface_proc_t *caller)
{
    if(caller == NULL) return PROC_VIS_NONE;
    uid_t uid = proc_getuid(caller);
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
            return proc_getuid(caller) == proc_getuid(target);
        case PROC_VIS_SELF:
            return caller->bsd.kp_proc.p_pid == target->bsd.kp_proc.p_pid;
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
    memcpy(kp, &(proc->bsd), sizeof(kinfo_proc_t));
}

proc_list_err_t proc_snapshot_create(pid_t caller_pid,
                                     proc_snapshot_t **snapshot_out)
{
    if(snapshot_out == NULL)
    {
        return PROC_LIST_ERR_NULL;
    }
    
    *snapshot_out = NULL;
    
    ksurface_proc_t *caller = proc_for_pid(caller_pid);
    if(caller == NULL)
    {
        return PROC_LIST_ERR_PERM;
    }
    
    proc_snapshot_t *snap = malloc(sizeof(proc_snapshot_t) + (PROC_MAX * sizeof(kinfo_proc_t)));
    if(snap == NULL)
    {
        proc_release(caller);
        return PROC_LIST_ERR_NO_SPACE;
    }
    
    snap->count = 0;
    snap->timestamp = _get_time_ms();
    
    proc_visibility_t vis = get_proc_visibility(caller);
    rcu_read_lock(&(ksurface->proc_info.rcu));
    uint32_t proc_count = atomic_load(&(ksurface->proc_info.proc_count));
    for(uint32_t i = 0; i < proc_count; i++) {
        ksurface_proc_t *p = rcu_dereference(ksurface->proc_info.proc[i]);
        if(proc_retain(p))
        {
            if(can_see_process(caller, p, vis))
            {
                copy_proc_to_user(p, &snap->kp[snap->count++]);
            }
            proc_release(p);
        }
    }
    rcu_read_unlock(&(ksurface->proc_info.rcu));
    proc_release(caller);
    *snapshot_out = snap;
    return PROC_LIST_OK;
}

void proc_snapshot_free(proc_snapshot_t *snap)
{
    free(snap);
}
