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

#ifndef SURFACE_SYS_SYSCALL_H
#define SURFACE_SYS_SYSCALL_H

/* headers to syscall handlers*/
#import <LindChain/ProcEnvironment/Surface/sys/kill.h>
#import <LindChain/ProcEnvironment/Surface/sys/bamset.h>
#import <LindChain/ProcEnvironment/Surface/sys/proctb.h>
#import <LindChain/ProcEnvironment/Surface/sys/setuid.h>
#import <LindChain/ProcEnvironment/Surface/sys/setgid.h>
#import <LindChain/ProcEnvironment/Surface/sys/getent.h>
#import <LindChain/ProcEnvironment/Surface/sys/getpid.h>
#import <LindChain/ProcEnvironment/Surface/sys/getuid.h>
#import <LindChain/ProcEnvironment/Surface/sys/getgid.h>
#import <LindChain/ProcEnvironment/Surface/sys/gethostname.h>
#import <LindChain/ProcEnvironment/Surface/sys/sethostname.h>
#include <sys/syscall.h>

/* syscalls */
#define SYS_KILL SYS_kill           /* killing other processes */
#define SYS_SETUID SYS_setuid       /* sets user identifier of a process */
#define SYS_SETEUID SYS_seteuid     /* sets effective user identifier of a process */
#define SYS_SETGID SYS_setgid       /* sets group identifier of a process */
#define SYS_SETEGID SYS_setegid     /* sets effective group identifier of a process */
#define SYS_SETREUID SYS_setreuid   /* sets real and effective user identifier, used for setruid() too */
#define SYS_SETREGID SYS_setregid   /* sets real and effective group identifier, used for setrgid() too */
#define SYS_GETPID SYS_getpid       /* gets the process identifier of the calling process */
#define SYS_GETPPID SYS_getppid     /* gets the parent process identifier of the calling process */
#define SYS_GETUID SYS_getuid       /* gets the user identifier of the calling process */
#define SYS_GETEUID SYS_geteuid     /* gets the effective user identifier of the calling process */
#define SYS_GETGID SYS_getgid       /* gets the group identifier of the calling process */
#define SYS_GETEGID SYS_getegid     /* gets the effective group identifier of the calling process */
#define SYS_PROC_INFO SYS_proc_info   /* MARK: Implement this the next! */

/* nyxian syscalls for now */
#define SYS_BAMSET 200              /* setting audio background mode */
#define SYS_PROCTB 201              /* getting process table MARK: will be SYS_SYSCTL later */
#define SYS_GETENT 202              /* getting processes entitlements */
#define SYS_GETHOSTNAME 203         /* later replaced with XNU SYSCTL semantics */
#define SYS_SETHOSTNAME 204         /* later replaced with XNU SYSCTL semantics */

#define SYS_N 19

typedef struct {
    const char *name;
    uint32_t sysnum;
    syscall_handler_t hndl;
} syscall_list_item_t;

extern syscall_list_item_t sys_list[SYS_N];

#endif /* SURFACE_SYS_SYSCALL_H */
