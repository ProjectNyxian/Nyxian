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
    PROC_VIS_NONE = 0,  /* allows a process to see nothing, usually used as error */
    PROC_VIS_SAME_SID,  /* allows a process to see processes with the same sid */
    PROC_VIS_SAME_UID,  /* allows a process to see processes with the same uid */
    PROC_VIS_ALL,       /* allows a process to see all processes */
} proc_visibility_t;

/* Radix tree context */
typedef struct {
    ksurface_proc_copy_t *caller;
    proc_visibility_t vis;
    uint32_t count;
    kinfo_proc_t *kp;
} proc_list_radix_walker_t;

/* Side quests xD */
proc_visibility_t get_proc_visibility(ksurface_proc_copy_t *caller);
bool can_see_process(ksurface_proc_copy_t *caller, ksurface_proc_t *target, proc_visibility_t vis);
static inline void copy_proc_to_user(ksurface_proc_t *proc, kinfo_proc_t *kp);

/* Actual syscall handler */
ksurface_return_t proc_list(ksurface_proc_copy_t *proc_copy, kinfo_proc_t **kp, uint32_t *count);

#endif /* PROC_COPYLIST_H */
