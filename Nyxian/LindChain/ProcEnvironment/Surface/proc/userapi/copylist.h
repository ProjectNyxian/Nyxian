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

#ifndef PROC_USERAPI_COPYLIST_H
#define PROC_USERAPI_COPYLIST_H

#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/Surface/proc/userapi/ddosfence.h>

typedef enum {
    PROC_LIST_OK = 0,
    PROC_LIST_ERR_NULL,
    PROC_LIST_ERR_PERM,
    PROC_LIST_ERR_RATE_LIMIT,
    PROC_LIST_ERR_NO_SPACE,
    PROC_LIST_ERR_FAULT,
} proc_list_err_t;

typedef enum {
    PROC_VIS_NONE = 0,
    PROC_VIS_SELF,
    PROC_VIS_SAME_UID,
    PROC_VIS_ALL,
} proc_visibility_t;

/* Snapshot of processes */
typedef struct {
    uint32_t count;
    uint64_t timestamp;
    kinfo_proc_t kp[];
} proc_snapshot_t;

/* Side quests xD */
proc_visibility_t get_proc_visibility(ksurface_proc_t *caller);
bool can_see_process(ksurface_proc_t *caller, ksurface_proc_t *target, proc_visibility_t vis);
static inline void copy_proc_to_user(ksurface_proc_t *proc, kinfo_proc_t *kp);

/* Actual syscall handler */
proc_list_err_t proc_list_get(pid_t caller_pid, ddos_fence_t *df, kinfo_proc_t *kp, uint32_t buffer_size, uint32_t *count_out);
proc_list_err_t proc_list_count(pid_t caller_pid, ddos_fence_t *df, uint32_t *count_out);
proc_list_err_t proc_snapshot_create(pid_t caller_pid, proc_snapshot_t **snapshot_out);
void proc_snapshot_free(proc_snapshot_t *snap);

#endif /* PROC_USERAPI_COPYLIST_H */
