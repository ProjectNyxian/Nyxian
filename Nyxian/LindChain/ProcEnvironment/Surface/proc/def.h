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
#define proc_getpid(proc) proc.bsd.kp_proc.p_pid
#define proc_getppid(proc) proc.bsd.kp_eproc.e_ppid
#define proc_getentitlements(proc) proc.entitlements

#define proc_setpid(proc, pid) proc.bsd.kp_proc.p_pid = pid
#define proc_setppid(proc, ppid) proc.bsd.kp_proc.p_oppid = ppid; proc.bsd.kp_eproc.e_ppid = ppid; proc.bsd.kp_eproc.e_pgid = ppid
#define proc_setentitlements(proc, entitlement) proc.entitlements = entitlement

/// UID Helper macros
#define proc_getuid(proc) proc.bsd.kp_eproc.e_ucred.cr_uid
#define proc_getruid(proc) proc.bsd.kp_eproc.e_pcred.p_ruid
#define proc_getsvuid(proc) proc.bsd.kp_eproc.e_pcred.p_svuid

#define proc_setuid(proc, uid) proc.bsd.kp_eproc.e_ucred.cr_uid = uid
#define proc_setruid(proc, ruid) proc.bsd.kp_eproc.e_pcred.p_ruid = ruid
#define proc_setsvuid(proc, svuid) proc.bsd.kp_eproc.e_pcred.p_svuid = svuid

/// GID Helper macros
#define proc_getgid(proc) proc.bsd.kp_eproc.e_ucred.cr_groups[0]
#define proc_getrgid(proc) proc.bsd.kp_eproc.e_pcred.p_rgid
#define proc_getsvgid(proc) proc.bsd.kp_eproc.e_pcred.p_svgid

#define proc_setgid(proc, gid) proc.bsd.kp_eproc.e_ucred.cr_groups[0] = gid
#define proc_setrgid(proc, rgid) proc.bsd.kp_eproc.e_pcred.p_rgid = rgid
#define proc_setsvgid(proc, svgid) proc.bsd.kp_eproc.e_pcred.p_svgid = svgid

#define pid_is_launchd(pid) pid == 1

#define PID_LAUNCHD 1

#endif /* PROC_DEF_H */
