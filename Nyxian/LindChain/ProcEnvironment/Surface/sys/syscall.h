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
#import <LindChain/ProcEnvironment/Surface/sys/proc/kill.h>
#import <LindChain/ProcEnvironment/Surface/sys/compat/bamset.h>
#import <LindChain/ProcEnvironment/Surface/sys/compat/proctb.h>
#import <LindChain/ProcEnvironment/Surface/sys/cred/setuid.h>
#import <LindChain/ProcEnvironment/Surface/sys/cred/setgid.h>
#import <LindChain/ProcEnvironment/Surface/sys/compat/getent.h>
#import <LindChain/ProcEnvironment/Surface/sys/cred/getpid.h>
#import <LindChain/ProcEnvironment/Surface/sys/cred/getuid.h>
#import <LindChain/ProcEnvironment/Surface/sys/cred/getgid.h>
#import <LindChain/ProcEnvironment/Surface/sys/host/gethostname.h>
#import <LindChain/ProcEnvironment/Surface/sys/host/sethostname.h>
#import <LindChain/ProcEnvironment/Surface/sys/compat/gettask.h>
#import <LindChain/ProcEnvironment/Surface/sys/compat/signexec.h>
#import <LindChain/ProcEnvironment/Surface/sys/compat/procpath.h>
#import <LindChain/ProcEnvironment/Surface/sys/compat/procbsd.h>
#import <LindChain/ProcEnvironment/Surface/sys/compat/handoffep.h>
#import <LindChain/ProcEnvironment/Surface/sys/cred/getsid.h>
#import <LindChain/ProcEnvironment/Surface/sys/cred/setsid.h>
#include <sys/syscall.h>

/* additional nyxian syscalls for now */
#define SYS_bamset      750         /* setting audio background mode */
#define SYS_proctb      751         /* getting process table MARK: will be SYS_SYSCTL later */
#define SYS_getent      752         /* getting processes entitlements */
#define SYS_gethostname 753         /* later replaced with XNU SYSCTL semantics */
#define SYS_sethostname 754         /* later replaced with XNU SYSCTL semantics */
#define SYS_gettask     755         /* gets task port */
#define SYS_signexec    756         /* uses file descriptor passed by guest to sign executable */
#define SYS_procpath    757         /* gets process path of a pid */
#define SYS_procbsd     758         /* gets process bsd of a pid */
#define SYS_handoffep   759         /* handoff exception port to kvirt */

#define SYS_N 26

typedef struct {
    const char *name;
    uint32_t sysnum;
    syscall_handler_t hndl;
} syscall_list_item_t;

extern syscall_list_item_t sys_list[SYS_N];

#endif /* SURFACE_SYS_SYSCALL_H */
