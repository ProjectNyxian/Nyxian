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
#include <sys/syscall.h>

/* syscalls */
#define SYS_KILL SYS_kill       /* killing other processes */
#define SYS_BAMSET 2            /* setting audio background mode */
#define SYS_PROCTB 3            /* getting process table MARK: will be SYS_SYSCTL later */
#define SYS_SETUID SYS_setuid   /* sets user identifier of a process */
#define SYS_SETRUID SYS_setruid /* sets real user identifier of a process */
#define SYS_SETEUID SYS_seteuid /* sets effective user identifier of a process */
#define SYS_SETGID SYS_setgid   /* sets group identifier of a process */
#define SYS_SETRGID SYS_setrgid /* sets real group identifier of a process */
#define SYS_SETEGID SYS_setegid /* sets effective group identifier of a process */
#define SYS_SETREUID SYS_setreuid
#define SYS_SETREGID SYS_setregid

#endif /* SURFACE_SYS_SYSCALL_H */
