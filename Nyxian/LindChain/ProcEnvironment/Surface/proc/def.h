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

#ifndef PROC_DEF_H
#define PROC_DEF_H

/// Helper macros
#define proc_getpid(proc) proc->kproc.kcproc.bsd.kp_proc.p_pid
#define proc_getppid(proc) proc->kproc.kcproc.bsd.kp_eproc.e_ppid
#define proc_getentitlements(proc) proc->kproc.kcproc.nyx.entitlements

#define proc_setpid(proc, pid) proc->kproc.kcproc.bsd.kp_proc.p_pid = pid
#define proc_setppid(proc, ppid) proc->kproc.kcproc.bsd.kp_proc.p_oppid = ppid; proc->kproc.kcproc.bsd.kp_eproc.e_ppid = ppid; proc->kproc.kcproc.bsd.kp_eproc.e_pgid = ppid
#define proc_setentitlements(proc, entitlement) proc->kproc.kcproc.nyx.entitlements = entitlement

/// UID Helper macros
#define proc_getruid(proc) proc->kproc.kcproc.bsd.kp_eproc.e_pcred.p_ruid
#define proc_geteuid(proc) proc->kproc.kcproc.bsd.kp_eproc.e_ucred.cr_uid
#define proc_getsvuid(proc) proc->kproc.kcproc.bsd.kp_eproc.e_pcred.p_svuid

#define proc_setruid(proc, ruid) proc->kproc.kcproc.bsd.kp_eproc.e_pcred.p_ruid = ruid
#define proc_seteuid(proc, uid) proc->kproc.kcproc.bsd.kp_eproc.e_ucred.cr_uid = uid
#define proc_setsvuid(proc, svuid) proc->kproc.kcproc.bsd.kp_eproc.e_pcred.p_svuid = svuid

/// GID Helper macros
#define proc_getrgid(proc) proc->kproc.kcproc.bsd.kp_eproc.e_pcred.p_rgid
#define proc_getegid(proc) proc->kproc.kcproc.bsd.kp_eproc.e_ucred.cr_groups[0]
#define proc_getsvgid(proc) proc->kproc.kcproc.bsd.kp_eproc.e_pcred.p_svgid

#define proc_setrgid(proc, rgid) proc->kproc.kcproc.bsd.kp_eproc.e_pcred.p_rgid = rgid
#define proc_setegid(proc, gid) proc->kproc.kcproc.bsd.kp_eproc.e_ucred.cr_groups[0] = gid
#define proc_setsvgid(proc, svgid) proc->kproc.kcproc.bsd.kp_eproc.e_pcred.p_svgid = svgid

#define proc_setmobilecred(proc) proc_setruid(proc, 501); proc_seteuid(proc, 501); proc_setsvuid(proc, 501); proc_setrgid(proc, 501); proc_setegid(proc, 501); proc_setsvgid(proc, 501)

#define pid_is_launchd(pid) pid == 1

#define PID_LAUNCHD 1

#define kernel_proc_ ksurface->proc_info.kern_proc

#endif /* PROC_DEF_H */
