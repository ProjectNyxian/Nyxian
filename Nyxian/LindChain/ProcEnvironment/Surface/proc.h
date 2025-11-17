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

#ifndef PROCENVIRONMENT_PROC_H
#define PROCENVIRONMENT_PROC_H

#import <LindChain/ProcEnvironment/Surface/surface.h>

/// Helper macros
#define proc_getpid(proc) proc.bsd.kp_proc.p_pid
#define proc_getppid(proc) proc.bsd.kp_eproc.e_ppid
#define proc_getentitlements(proc) proc.entitlements

/// UID Helper macros
#define proc_getuid(proc) proc.bsd.kp_eproc.e_ucred.cr_uid
#define proc_getruid(proc) proc.bsd.kp_eproc.e_pcred.p_ruid
#define proc_getsvuid(proc) proc.bsd.kp_eproc.e_pcred.p_svuid

/// GID Helper macros
#define proc_getgid(proc) proc.bsd.kp_eproc.e_ucred.cr_groups[0]
#define proc_getrgid(proc) proc.bsd.kp_eproc.e_pcred.p_rgid
#define proc_getsvgid(proc) proc.bsd.kp_eproc.e_pcred.p_svgid

/// Returns a process structure for a given process identifier
ksurface_proc_t proc_object_for_pid(pid_t pid);

/// Removes a process structure for a given process identifier
void proc_object_remove_for_pid(pid_t pid);

/// Inserts a given process structure into the surface structure
void proc_object_insert(ksurface_proc_t object);

/// Returns a process structure at a given index
ksurface_proc_t proc_object_at_index(uint32_t index);

/// Returns if any process is allowed to spawn
BOOL proc_can_spawn(void);

/// Creates child process
BOOL proc_create_child_proc(pid_t ppid, pid_t pid, uid_t uid, gid_t gid, NSString *executablePath, PEEntitlement entitlement);

/// Removes process object from process table
void proc_object_remove_for_pid(pid_t pid);

#endif /* PROCENVIRONMENT_PROC_H */
