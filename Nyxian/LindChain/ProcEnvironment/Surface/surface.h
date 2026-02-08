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
#include <LindChain/ProcEnvironment/Surface/radix/radix.h>
#import <LindChain/Private/FoundationPrivate.h>
#import <LindChain/Private/UIKitPrivate.h>
#import <LindChain/ProcEnvironment/Syscall/mach_syscall_server.h>
#import <LindChain/ProcEnvironment/Syscall/mach_syscall_client.h>
#include <pthread.h>

enum kSurfaceError {
    kSurfaceErrorSuccess            = 0,
    kSurfaceErrorUndefined          = 1,
    kSurfaceErrorNullPtr            = 2,
    kSurfaceErrorNotFound           = 3,
    kSurfaceErrorNotHoldingLock     = 4,
    kSurfaceErrorOutOfBounds        = 5,
    kSurfaceErrorDenied             = 6,
    kSurfaceErrorAlreadyExists      = 7,
    kSurfaceErrorFailed             = 8,
    kSurfaceErrorProcessDead        = 9,
    kSurfaceErrorPidInUse           = 10,
    kSurfaceErrorNoMemory           = 11,
    kSurfaceErrorRetentionFailed    = 12,
};

typedef unsigned char ksurface_error_t;

/// Limits

/*
 * im sorry if you complain about the
 * amount of maximum processes, dont
 * complain about this to me, complain
 * about this to apple, their the reason
 * why, launchd doesnt let us spawn more.
 */
#define PROC_MAX 1024

/*
 * why would a process need more than 128
 * childs?
 */
#define CHILD_PROC_MAX 128

/*
 * the maximum count of pid that the
 * radix tree supports.
 */
#define PID_MAX 1048575

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

    /*
     * reference count of this processes
     * if it hits zero it will release
     * automatically.
     */
    _Atomic int refcount;
    
    /*
     * dead boolean value marks a process
     * as effectively dead, any new retains
     * will fail cuz it doesnt matter anymore
     * what a syscall or kernel operation
     * might wanna do with this process
     * as its literally dead.
     */
    _Atomic bool dead;
    
    /*
     * main read-write lock of this structure,
     * mainly used when modifying kcproc.
     */
    pthread_rwlock_t rwlock;
    
    /*
     * the actual process structure, not meant
     * to be copied tho.
     */
    struct kproc {
        
        /*
         * task port of a process, the biggest permitive
         * a other process can have over a process, once
         * given to a other process we cannot take it back
         * we cannot control the mach kernel!
         */
        task_t task;
        
        /*
         * exception port of a process that has debugging
         * enabled, will cause us to receive a right to
         * their exception port, which might be used to
         * trigger the exception handler in the process.
         */
        mach_port_t eport;
        
        /*
         * process structure used to sign reference contracts
         * with child processes.
         */
        struct kchildren {
            
            /*
             * special mutex to make sure nothing happens at the same
             * time on kchildren.
             */
            pthread_mutex_t mutex;
            
            /* the reference held by the child of the parent */
            ksurface_proc_t *parent;
            
            /* children references the parent holds */
            ksurface_proc_t *children[CHILD_PROC_MAX];
            
            /*
             * the index at which the child exist in its parents
             * children array.
             */
            uint64_t parent_cld_idx;
            
            /* count of children in the children array */
            uint64_t children_cnt;
        } children;
        
        /*
         * copyable process structure, includes all process properties
         * which can change rapidly.
         */
        struct kcproc {
            
            /* bsd structure of our process structure */
            kinfo_proc_t bsd;
            
            /* nyxian specific process structure */
            struct knyx_proc {
                
                /* executable path at which the macho is located at */
                char executable_path[PATH_MAX];
                
                /* entitlements the process has */
                PEEntitlement entitlements;
            } nyx;
        } kcproc;
    } kproc;
};

/// Structure for the copy API
typedef struct {
    /* reference back to copied process */
    ksurface_proc_t *proc;
    
    /*
     * the actual process structure, not meant
     * to be copied tho. In this case its here
     * for convenience.
     */
    struct {
        
        /*
         * copyable process structure, includes all process properties
         * which can change rapidly.
         */
        ksurface_kcproc_t kcproc;
    } kproc;
} ksurface_proc_copy_t;

/// Structure that holds surface information and other structures
typedef struct {
    
    /*
     * syscall server which handles certain
     * syscalls made by userspace processes.
     */
    syscall_server_t *sys_server;
    
    /*
     * structure that holds host information.
     * Such as hostname.
     */
    struct {
        
        /*
         * lock making sure rw happens not at
         * the same time
         */
        pthread_rwlock_t struct_lock;
        
        /*
         * hostname buffer, holding current hostname.
         * which can be changed by userspace with
         * enough entitlements.
         */
        char hostname[MAXHOSTNAMELEN];
    } host_info;
    
    /*
     * process information structure.
     * It holds all processes that run
     * inside of nyxian and manages them.
     */
    struct {
        
        /* rwlock securing structures */
        pthread_rwlock_t struct_lock;
        
        /* rwlock securing structures */
        pthread_rwlock_t task_lock;
        
        /*
         * count of processes currently running
         * inside of nyxian.
         */
        uint32_t proc_count;
        
        /*
         * radix tree where all processes are
         * listed inside.
         */
        radix_tree_t tree;
        
        /*
         * kernel process(aka Nyxian it self
         * running as host for the glient
         * processes).
         */
        ksurface_proc_t *kern_proc;
    } proc_info;
} ksurface_mapping_t;

/* Internal kernel information */
extern ksurface_mapping_t *ksurface;

void kern_sethostname(NSString *hostname);

void ksurface_kinit(void);

#endif /* PROCENVIRONMENT_SURFACE_H */
