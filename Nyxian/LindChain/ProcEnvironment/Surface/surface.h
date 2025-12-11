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

/// Limits
#define PROC_MAX 750
#define PID_MAX 1048575
#define CHILD_PROC_MAX PROC_MAX
#define SURFACE_MAGIC 0xDEADBEEF

/// Nyxian process typedefinitions
typedef struct ksurface_proc ksurface_proc_t;
typedef struct kduy_proc kduy_proc_t;
typedef struct kchildren ksurface_kproc_children_t;
typedef struct kinfo_proc kinfo_proc_t;
typedef struct kcproc ksurface_kcproc_t;
typedef struct kproc ksurface_kproc_t;
typedef struct knyx_proc knyx_proc_t;

/// Nyxian process structure
struct ksurface_proc {
    _Atomic int refcount;
    _Atomic bool dead;
    pthread_rwlock_t rwlock;
    struct kproc {
        /*
         MARK: will be used later as the main structure, called duy to honor his work
         
         struct kduy_proc {
             __strong NSExtension *nsExtension;
             __strong RBSProcessHandle *rbsProcessHandle;
             __strong RBSProcessMonitor *processMonitor;
             __strong FBScene *fbScene;
         } duy;
         */
        struct kchildren {
            ksurface_proc_t *parent;
            ksurface_proc_t *children[CHILD_PROC_MAX];
            uint64_t parent_cld_idx;
            uint64_t children_cnt;
            pthread_mutex_t mutex;
        } children;
        struct kcproc {
            kinfo_proc_t bsd;
            struct knyx_proc {
                char executable_path[PATH_MAX];
                PEEntitlement entitlements;
            } nyx;
        } kcproc;
    } kproc;
};

/// Structure for the copy API
typedef struct {
    ksurface_proc_t *proc;
    struct {
        ksurface_kcproc_t kcproc;
    } kproc;
} ksurface_proc_copy_t;

/// Structure that holds surface information and other structures
typedef struct {
    uint32_t magic;
    syscall_server_t *sys_server;
    struct {
        pthread_rwlock_t rwlock;
        char hostname[MAXHOSTNAMELEN];
    } host_info;
    struct {
        pthread_rwlock_t rwlock;
        uint32_t proc_count;
        radix_tree_t tree;
        ksurface_proc_t *kern_proc;
    } proc_info;
} ksurface_mapping_t;

/* Internal kernel information */
extern ksurface_mapping_t *ksurface;

void kern_sethostname(NSString *hostname);
void ksurface_kinit(void);

#endif /* PROCENVIRONMENT_SURFACE_H */
