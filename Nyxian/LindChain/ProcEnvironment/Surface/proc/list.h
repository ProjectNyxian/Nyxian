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

#ifndef PROC_COPYLIST_H
#define PROC_COPYLIST_H

#include <LindChain/ProcEnvironment/Surface/proc/proc.h>

typedef enum {
    PROC_VIS_NONE = 0,      /* allows a process to see nothing */
    PROC_VIS_SAME_SID = 1,  /* allows a process to see processes with the same sid */
    PROC_VIS_ALL = 2,       /* allows a process to see all processes */
} proc_visibility_t;

typedef enum {
    PROC_FLV_ALL = 0,
    PROC_FLV_SID = 1,
    PROC_FLV_UID = 2,
    PROC_FLV_RUID = 3,
    PROC_FLV_PID = 4,
    PROC_FLV_PGID = 5
} proc_flavour_t;

/* Side quests xD */
proc_visibility_t proc_get_proc_visibility(ksurface_proc_snapshot_t *caller);
bool proc_can_see_proc(ksurface_proc_snapshot_t *caller, ksurface_proc_t *target, proc_visibility_t vis);
bool proc_is_flavour_matching(ksurface_proc_t *target, proc_flavour_t flavour, pid_t dsid);

bool proc_pgrp_exists(pid_t pgid);
bool proc_pgrp_exists_in_session(pid_t pgid, pid_t sid);

/* Actual syscall handler */
kern_return_t proc_list(ksurface_proc_snapshot_t *proc_snapshot, kinfo_proc_t **kp, size_t *len, proc_flavour_t flavour, pid_t dsid);

#endif /* PROC_COPYLIST_H */
