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

#ifndef PROCENVIRONMENT_SURFACE_H
#define PROCENVIRONMENT_SURFACE_H

#import <Foundation/Foundation.h>
#include <sys/sysctl.h>
#include <limits.h>
#include <LindChain/ProcEnvironment/Surface/lock/seqlock.h>
#import <LindChain/ProcEnvironment/Surface/entitlement.h>
#import <LindChain/ProcEnvironment/Object/MappingPortObject.h>

/// Structure that holds process information
typedef struct {
    /* Real structure */
    struct kinfo_proc bsd;
    
    /* Now we come to my other things */
    /* Because its important */
    char path[PATH_MAX];
    
    /* Storing override flag for TASK_UNSPECIFIED */
    bool force_task_role_override;
    task_role_t task_role_override;
    
    /* Entitlements*/
    PEEntitlement entitlements;
} ksurface_proc_t;

/* Interestingly launchd only allows us to have 1000 extensions to execute, which is still unsafe, so i reduced it to 750 */
#define PROC_MAX 750

/// Structure that holds surface information and other structures
typedef struct {
    /* Spinlock */
    seqlock_t seqlock;
    
    /* System */
    uint32_t magic;
    char hostname[MAXHOSTNAMELEN];
    
    /* Proc */
    uint32_t proc_count;
    ksurface_proc_t proc_info[PROC_MAX];
} ksurface_mapping_t;

/* Surface Macros */
#define SURFACE_MAGIC 0xFABCDEFB

/* Shared properties */
extern ksurface_mapping_t *surface;

/* Handoff */

/// Returns a process surface file handle to perform a handoff over XPC
MappingPortObject *proc_surface_for_pid(pid_t pid);

/* sysctl */
int proc_sysctl_listproc(void *buffer, size_t buffersize, size_t *needed_out);

void kern_sethostname(NSString *hostname);

void proc_surface_init(void);

#endif /* PROCENVIRONMENT_SURFACE_H */
