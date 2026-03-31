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

#ifndef PROC_COPYLIST_H
#define PROC_COPYLIST_H

#include <LindChain/ProcEnvironment/Surface/proc/proc.h>

typedef enum {
    PROC_VIS_NONE = 0,      /* allows a process to see nothing, usually used as error */
    PROC_VIS_SAME_SID = 1,  /* allows a process to see processes with the same sid */
    PROC_VIS_SAME_UID = 2,  /* allows a process to see processes with the same uid */
    PROC_VIS_ALL = 3,       /* allows a process to see all processes */
} proc_visibility_t;

typedef enum {
    PROC_FLV_ALL = 0,
    PROC_FLV_SID = 1,
    PROC_FLV_UID = 2,
    PROC_FLV_RUID = 3,
    PROC_FLV_PID = 4
} proc_flavour_t;

/* Radix tree context */
typedef struct {
    ksurface_proc_snapshot_t *caller;
    proc_visibility_t vis;
    proc_flavour_t flavour;
    pid_t dsid;
    size_t len;
    kinfo_proc_t *kp;
} proc_list_radix_walker_t;

/* Side quests xD */
proc_visibility_t get_proc_visibility(ksurface_proc_snapshot_t *caller);
bool can_see_process(ksurface_proc_snapshot_t *caller, ksurface_proc_t *target, proc_visibility_t vis);
bool is_flavour_matching(ksurface_proc_t *target, proc_flavour_t flavour, pid_t dsid);

/* Actual syscall handler */
ksurface_return_t proc_list(ksurface_proc_snapshot_t *proc_snapshot, kinfo_proc_t **kp, size_t *len, proc_flavour_t flavour, pid_t dsid);

#endif /* PROC_COPYLIST_H */
