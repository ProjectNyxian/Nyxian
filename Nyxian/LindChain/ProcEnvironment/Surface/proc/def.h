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

#ifndef PROC_DEF_H
#define PROC_DEF_H

#import <LindChain/ProcEnvironment/Surface/limits.h>
#import <LindChain/ProcEnvironment/Surface/libkern/obj/kvobject.h>
#include <LindChain/ProcEnvironment/Surface/trust/trust.h>
#include <sys/sysctl.h>

#ifndef PE_SUPPLEMENTARY_GROUPS_MAX
#define PE_SUPPLEMENTARY_GROUPS_MAX 32
#endif

/// Helper macros
#define proc_getpid(proc) ((proc)->bsd.kp_proc.p_pid)
#define proc_getpidv(proc) ((proc)->nyx.pidv)
#define proc_getppid(proc) ((proc)->bsd.kp_eproc.e_ppid)
#define proc_getentitlements(proc) ((proc)->nyx.entitlements)
#define proc_getmaxentitlements(proc) ((proc)->nyx.maxEntitlements)

#define proc_setpid(proc, pid) (proc)->bsd.kp_proc.p_pid = pid
#define proc_setppid(proc, ppid) do { \
    (proc)->bsd.kp_proc.p_oppid = (ppid); \
    (proc)->bsd.kp_eproc.e_ppid = (ppid); \
} while(0)
#define proc_setpidv(proc, spidv) (proc)->nyx.pidv = (spidv)
#define proc_setentitlements(proc, entitlement) (proc)->nyx.entitlements = entitlement
#define proc_setmaxentitlements(proc, entitlement) (proc)->nyx.maxEntitlements = entitlement

#define proc_did_change_credentials(proc) ((proc)->bsd.kp_proc.p_flag & P_SUGID)

/// UID Helper macros
#define proc_getruid(proc) ((proc)->bsd.kp_eproc.e_pcred.p_ruid)
#define proc_geteuid(proc) ((proc)->bsd.kp_eproc.e_ucred.cr_uid)
#define proc_getsvuid(proc) ((proc)->bsd.kp_eproc.e_pcred.p_svuid)

#define proc_setruid(proc, ruid) (proc)->bsd.kp_eproc.e_pcred.p_ruid = ruid
#define proc_seteuid(proc, uid) (proc)->bsd.kp_eproc.e_ucred.cr_uid = uid
#define proc_setsvuid(proc, svuid) (proc)->bsd.kp_eproc.e_pcred.p_svuid = svuid

/// GID Helper macros
#define proc_getrgid(proc) ((proc)->bsd.kp_eproc.e_pcred.p_rgid)
#define proc_getegid(proc) ((proc)->bsd.kp_eproc.e_ucred.cr_groups[0])
#define proc_getsvgid(proc) ((proc)->bsd.kp_eproc.e_pcred.p_svgid)

#define proc_setrgid(proc, rgid) (proc)->bsd.kp_eproc.e_pcred.p_rgid = rgid
#define proc_setegid(proc, gid) (proc)->bsd.kp_eproc.e_ucred.cr_groups[0] = gid
#define proc_setsvgid(proc, svgid) (proc)->bsd.kp_eproc.e_pcred.p_svgid = svgid

/// SID + PGID Helper macros
#define proc_getsid(proc) ((proc)->nyx.sid)
#define proc_setsid(proc, ssid) ((proc)->nyx.sid = (ssid))

#define proc_getpgid(proc) ((proc)->nyx.pgid)
#define proc_setpgid(proc, spgid) do { \
    (proc)->nyx.pgid = (spgid); \
    (proc)->bsd.kp_eproc.e_pgid = (spgid); \
} while(0)

#define proc_setmobilecred(proc) proc_setruid(proc, 501); proc_seteuid(proc, 501); proc_setsvuid(proc, 501); proc_setrgid(proc, 501); proc_setegid(proc, 501); proc_setsvgid(proc, 501)
#define proc_setrootcred(proc) proc_setruid(proc, 0); proc_seteuid(proc, 0); proc_setsvuid(proc, 0); proc_setrgid(proc, 0); proc_setegid(proc, 0); proc_setsvgid(proc, 0)

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
     * task port of a process, the biggest primitive
     * a other process can have over a process, once
     * given to a other process we cannot take it back
     * we cannot control the mach kernel!
     */
    bool in_tfp_handoff;
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
        /* session and process group identifiers */
        pid_t sid;
        pid_t pgid;
        int pidv;
        
        /* BSD login identity and supplementary groups */
        char login_name[MAXLOGNAME];
        uint16_t login_name_len;
        gid_t supplementary_groups[PE_SUPPLEMENTARY_GROUPS_MAX];
        uint16_t supplementary_group_count;
        
        /* wait4 markers */
        int64_t p_status;
        
        uint64_t start_abstime;
        uint64_t exit_abstime;
        
        /* for creation from it, please hold lock to the proc object */
        ksurface_trust_identity_t *identity;
        
        PEEntitlementFlags entitlements;
        PEEntitlementFlags maxEntitlements;
    } nyx;
};

typedef enum: uint32_t {
    kProcEventTypeKill =        1ull << 6,
    kProcEventTypeWait4 =       1ull << 7,
    kProcEventTypeWaitTask =    1ull << 8,
} ProcEventType;

#endif /* PROC_DEF_H */
