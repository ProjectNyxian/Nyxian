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
#import <LindChain/ProcEnvironment/Surface/entitlement.h>
#import <LindChain/ProcEnvironment/Object/MappingPortObject.h>
#include <LindChain/ProcEnvironment/Surface/radix/radix.h>
#import <LindChain/Private/FoundationPrivate.h>
#import <LindChain/Private/UIKitPrivate.h>
#import <LindChain/ProcEnvironment/Syscall/mach_syscall_server.h>
#import <LindChain/ProcEnvironment/Syscall/mach_syscall_client.h>
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
    kSurfaceErrorFailed         = 8,
    kSurfaceErrorProcessDead    = 9,
    kSurfaceErrorPidInUse       = 10,
    kSurfaceErrorNoMemory       = 11
};

typedef unsigned char ksurface_error_t;

#define PROC_MAX 750
#define PID_MAX 1048575
#define CHILD_PROC_MAX PROC_MAX
#define SURFACE_MAGIC 0xDEADBEEF

/// BSD process structure
typedef struct kinfo_proc kinfo_proc_t;

/// Nyxian process structure
typedef struct {
    char executable_path[PATH_MAX];
    bool force_task_role_override;
    task_role_t task_role_override;
    PEEntitlement entitlements;
} knyx_proc_t;

/// Structure to honor Duy Trans contributions
/// Why? Because his research is in this structure
typedef struct {
    __strong NSExtension *nsExtension;
    __strong RBSProcessHandle *rbsProcessHandle;
    __strong RBSProcessMonitor *processMonitor;
    __strong FBScene *fbScene;
} kduy_proc_t;

/// Structure that holds children of each process.. and a reference to each of those
/// This cannot be copied!!! This structure is extremely sensitive
/// The parent pointer and children pointer must all be referenced to eachother
typedef struct {
    void *parent;
    void *children[CHILD_PROC_MAX];
    uint64_t parent_cld_idx;
    uint64_t children_cnt;
    pthread_mutex_t mutex;
} ksurface_proc_children_t;

/// Structure that holds process information
typedef struct {
    _Atomic int refcount;
    _Atomic bool dead;
    pthread_rwlock_t rwlock;
    ksurface_proc_children_t cld;
    kinfo_proc_t bsd;
    knyx_proc_t nyx;
    
    /* will be used later */
    //kduy_proc_t duy;
} ksurface_proc_t;

typedef struct {
    kinfo_proc_t bsd;
    knyx_proc_t nyx;
    ksurface_proc_t *original;
} ksurface_proc_copy_t;

/// Host information
typedef struct {
    pthread_rwlock_t rwlock;
    char hostname[MAXHOSTNAMELEN];
} ksurface_host_info_t;

/// Process information
typedef struct {
    pthread_rwlock_t rwlock;
    uint32_t pcnt;
    ksurface_proc_t *kproc;
    radix_tree_t tree;
} ksurface_proc_info_t;

/// Structure that holds surface information and other structures
typedef struct {
    uint32_t magic;
    ksurface_host_info_t host_info;
    ksurface_proc_info_t proc_info;
    syscall_server_t *sys_server;
} ksurface_mapping_t;

/* Internal kernel information */
extern ksurface_mapping_t *ksurface;

void kern_sethostname(NSString *hostname);
void ksurface_kinit(void);

#endif /* PROCENVIRONMENT_SURFACE_H */
