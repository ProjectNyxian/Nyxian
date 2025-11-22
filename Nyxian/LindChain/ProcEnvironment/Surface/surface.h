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
#import <LindChain/Multitask/LDEProcessManager.h>

enum kSurfaceError {
    kSurfaceErrorSuccess        = 0,
    kSurfaceErrorUndefined      = 1,
    kSurfaceErrorNullPtr        = 2,
    kSurfaceErrorNotFound       = 3,
    kSurfaceErrorNotHoldingLock = 4, /* potentially for future */
    kSurfaceErrorOutOfBounds    = 5,
    kSurfaceErrorDenied         = 6,
    kSurfaceErrorAlreadyExists  = 7
};

typedef unsigned char ksurface_error_t;

#define PROC_MAX 750
#define CHILD_PROC_MAX PROC_MAX
#define SURFACE_MAGIC 0xFABCDEFB

/// BSD process structure
typedef struct kinfo_proc kinfo_proc_t;

/// Nyxian process structure
typedef struct {
    /* Black magic, night walker~~ She haunts me like no other~~ */
    char executable_path[PATH_MAX];
    bool force_task_role_override;
    task_role_t task_role_override;
    PEEntitlement entitlements;
} knyx_proc_t;

/// Structure that holds child process lists
typedef struct {
    void *children_proc[CHILD_PROC_MAX];
    unsigned long children_cnt;
} ksurface_proc_children_t;

/// Structure that holds process information
typedef struct {
    bool inUse;
    bool isValid;
    seqlock_t seqlock;
    void *parent;
    ksurface_proc_children_t children;
    kinfo_proc_t bsd;
    knyx_proc_t nyx;
} ksurface_proc_t;

/// Host information
typedef struct {
    char hostname[MAXHOSTNAMELEN];
} ksurface_host_info_t;

/// Process information
typedef struct {
    uint32_t proc_count;
    ksurface_proc_t proc[PROC_MAX];
} ksurface_proc_info_t;

/// Structure that holds surface information and other structures
typedef struct {
    uint32_t magic;
    seqlock_t seqlock;
    ksurface_host_info_t host_info;
    ksurface_proc_info_t proc_info;
} ksurface_mapping_t;

/* Shared mapping */
extern ksurface_mapping_t *surface;

/* Handoff */
MappingPortObject *proc_surface_for_pid(pid_t pid);

/* Sysctl */
int proc_sysctl_listproc(void *buffer, size_t buffersize, size_t *needed_out);

void kern_sethostname(NSString *hostname);

void proc_surface_init(void);

#endif /* PROCENVIRONMENT_SURFACE_H */
