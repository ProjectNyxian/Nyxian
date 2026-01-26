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

#ifndef PROC_COPYLIST_H
#define PROC_COPYLIST_H

#import <LindChain/ProcEnvironment/Surface/proc/proc.h>

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

/* Radix tree context */
typedef struct {
    ksurface_proc_copy_t *caller;
    proc_visibility_t vis;
    uid_t uid;
    proc_snapshot_t snap;
} proc_snapshot_radix_ctx;

/* Side quests xD */
proc_visibility_t get_proc_visibility(ksurface_proc_copy_t *caller);
bool can_see_process(ksurface_proc_copy_t *caller, ksurface_proc_t *target, proc_visibility_t vis);
static inline void copy_proc_to_user(ksurface_proc_t *proc, kinfo_proc_t *kp);

/* Actual syscall handler */
proc_list_err_t proc_snapshot_create(ksurface_proc_copy_t *proc, proc_snapshot_t **snapshot_out);
void proc_snapshot_free(proc_snapshot_t *snap);

/* Nyx copy */
bool proc_nyx_copy(ksurface_proc_copy_t *proc, pid_t targetPid, knyx_proc_t *nyx);

#endif /* PROC_COPYLIST_H */
