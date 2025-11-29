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
#include <LindChain/ProcEnvironment/Surface/lock/rcu/rcu.h>
#import <LindChain/ProcEnvironment/Surface/entitlement.h>
#import <LindChain/ProcEnvironment/Object/MappingPortObject.h>
#import <LindChain/Multitask/ProcessManager/LDEProcessManager.h>
#include <pthread.h>

enum kSurfaceError {
    kSurfaceErrorSuccess        = 0,
    kSurfaceErrorUndefined      = 1,
    kSurfaceErrorNullPtr        = 2,
    kSurfaceErrorNotFound       = 3,
    kSurfaceErrorNotHoldingLock = 4,
    kSurfaceErrorOutOfBounds    = 5,
    kSurfaceErrorDenied         = 6,
    kSurfaceErrorAlreadyExists  = 7,
    kSurfaceErrorFailed         = 8
};

typedef unsigned char ksurface_error_t;

#define PROC_MAX 750
#define CHILD_PROC_MAX PROC_MAX
#define SURFACE_MAGIC 0xDEADBEEF

/// BSD process structure
typedef struct kinfo_proc kinfo_proc_t;

/// Structure that holds process information
typedef struct {
    _Atomic int refcount;
    _Atomic bool dead;
    kinfo_proc_t bsd;
    struct {
        char executable_path[PATH_MAX];
        bool force_task_role_override;
        task_role_t task_role_override;
        PEEntitlement entitlements;
    } nyx;
} ksurface_proc_t;

/// Host information
typedef struct {
    rcu_state_t rcu;
    pthread_mutex_t wl;
    char hostname[MAXHOSTNAMELEN];
} ksurface_host_info_t;

/// Process information
typedef struct {
    rcu_state_t rcu;
    pthread_mutex_t wl;
    _Atomic uint32_t proc_count;
    ksurface_proc_t *proc[PROC_MAX];
} ksurface_proc_info_t;

/// Structure that holds surface information and other structures
typedef struct {
    uint32_t magic;
    ksurface_host_info_t host_info;
    ksurface_proc_info_t proc_info;
} ksurface_mapping_t;

/* Internal kernel information */
extern ksurface_mapping_t *ksurface;

void kern_sethostname(NSString *hostname);
void ksurface_init(void);

#endif /* PROCENVIRONMENT_SURFACE_H */
