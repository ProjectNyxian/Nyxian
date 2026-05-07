/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 mach-port-t

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

#ifndef PROC_DEF_H
#define PROC_DEF_H

#import <LindChain/ProcEnvironment/Surface/limits.h>
#import <LindChain/ProcEnvironment/Surface/entitlement.h>
#import <LindChain/ProcEnvironment/Surface/obj/kvobject.h>
#include <sys/sysctl.h>

/// Helper macros
#define proc_getpid(proc) proc->bsd.kp_proc.p_pid
#define proc_getppid(proc) proc->bsd.kp_eproc.e_ppid
#define proc_getentitlements(proc) proc->nyx.entitlements
#define proc_getmaxentitlements(proc) proc->nyx.max_entitlements

#define proc_setpid(proc, pid) proc->bsd.kp_proc.p_pid = pid
#define proc_setppid(proc, ppid) proc->bsd.kp_proc.p_oppid = ppid; proc->bsd.kp_eproc.e_ppid = ppid; proc->bsd.kp_eproc.e_pgid = ppid
#define proc_setentitlements(proc, entitlement) proc->nyx.entitlements = entitlement
#define proc_setmaxentitlements(proc, entitlement) proc->nyx.max_entitlements = entitlement

/// UID Helper macros
#define proc_getruid(proc) proc->bsd.kp_eproc.e_pcred.p_ruid
#define proc_geteuid(proc) proc->bsd.kp_eproc.e_ucred.cr_uid
#define proc_getsvuid(proc) proc->bsd.kp_eproc.e_pcred.p_svuid

#define proc_setruid(proc, ruid) proc->bsd.kp_eproc.e_pcred.p_ruid = ruid
#define proc_seteuid(proc, uid) proc->bsd.kp_eproc.e_ucred.cr_uid = uid
#define proc_setsvuid(proc, svuid) proc->bsd.kp_eproc.e_pcred.p_svuid = svuid

/// GID Helper macros
#define proc_getrgid(proc) proc->bsd.kp_eproc.e_pcred.p_rgid
#define proc_getegid(proc) proc->bsd.kp_eproc.e_ucred.cr_groups[0]
#define proc_getsvgid(proc) proc->bsd.kp_eproc.e_pcred.p_svgid

#define proc_setrgid(proc, rgid) proc->bsd.kp_eproc.e_pcred.p_rgid = rgid
#define proc_setegid(proc, gid) proc->bsd.kp_eproc.e_ucred.cr_groups[0] = gid
#define proc_setsvgid(proc, svgid) proc->bsd.kp_eproc.e_pcred.p_svgid = svgid

/// SID Helper macros
#define proc_getsid(proc) proc->nyx.sid
#define proc_setsid(proc, ssid) proc->nyx.sid = ssid

#define proc_setmobilecred(proc) proc_setruid(proc, 501); proc_seteuid(proc, 501); proc_setsvuid(proc, 501); proc_setrgid(proc, 501); proc_setegid(proc, 501); proc_setsvgid(proc, 501)
#define proc_setrootcred(proc) proc_setruid(proc, 0); proc_seteuid(proc, 0); proc_setsvuid(proc, 0); proc_setrgid(proc, 0); proc_setegid(proc, 0); proc_setsvgid(proc, 0)

#define pid_is_launchd(pid) pid == 1

#define PID_LAUNCHD 1

#define kernel_proc_ ksurface->proc_info.kern_proc

/// Nyxian process typedefinitions
typedef struct ksurface_proc ksurface_proc_t;
typedef struct ksurface_proc ksurface_proc_snapshot_t;
typedef struct kchildren ksurface_kproc_children_t;
typedef struct kinfo_proc kinfo_proc_t;
typedef struct knyx_proc knyx_proc_t;

/// Nyxian process structure
struct ksurface_proc {
    /* header of process */
    kvobject_t header;
    
    
    /*
     * task port of a process, the biggest permitive
     * a other process can have over a process, once
     * given to a other process we cannot take it back
     * we cannot control the mach kernel!
     */
    task_t task;
    
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
    
    
    /* bsd structure of our process structure */
    kinfo_proc_t bsd;
    
    /* nyxian specific process structure */
    struct knyx_proc {
        /* session identifier */
        pid_t sid;
        
        /* wait4 markers */
        int64_t p_status;
        
        /* executable path at which the macho is located at */
        char executable_path[PATH_MAX];
        
        /* entitlements the process has */
        PEEntitlement entitlements;
        PEEntitlement max_entitlements;
    } nyx;
};

#endif /* PROC_DEF_H */
