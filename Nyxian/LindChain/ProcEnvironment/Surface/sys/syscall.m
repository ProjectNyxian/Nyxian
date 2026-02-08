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

#import <LindChain/ProcEnvironment/Surface/sys/syscall.h>
#import <unistd.h>

/* list of syscalls for the kernel virtualization layer lol */
syscall_list_item_t sys_list[SYS_N] = {
    { .name = "SYS_KILL", .sysnum = SYS_KILL, .hndl = GET_SYSCALL_HANDLER(kill) },
    { .name = "SYS_BAMSET", .sysnum = SYS_BAMSET, .hndl = GET_SYSCALL_HANDLER(bamset) },
    { .name = "SYS_PROCTB", .sysnum = SYS_PROCTB, .hndl = GET_SYSCALL_HANDLER(proctb) },
    { .name = "SYS_SETUID", .sysnum = SYS_SETUID, .hndl = GET_SYSCALL_HANDLER(setuid) },
    { .name = "SYS_SETEUID", .sysnum = SYS_SETEUID, .hndl = GET_SYSCALL_HANDLER(seteuid) },
    { .name = "SYS_SETGID", .sysnum = SYS_SETGID, .hndl = GET_SYSCALL_HANDLER(setgid) },
    { .name = "SYS_SETEGID", .sysnum = SYS_SETEGID, .hndl = GET_SYSCALL_HANDLER(setegid) },
    { .name = "SYS_SETREUID", .sysnum = SYS_SETREUID, .hndl = GET_SYSCALL_HANDLER(setreuid) },
    { .name = "SYS_SETREGID", .sysnum = SYS_SETREGID, .hndl = GET_SYSCALL_HANDLER(setregid) },
    { .name = "SYS_GETENT", .sysnum = SYS_GETENT, .hndl = GET_SYSCALL_HANDLER(getent) },
    { .name = "SYS_GETPID", .sysnum = SYS_GETPID, .hndl = GET_SYSCALL_HANDLER(getpid) },
    { .name = "SYS_GETPPID", .sysnum = SYS_GETPPID, .hndl = GET_SYSCALL_HANDLER(getppid) },
    { .name = "SYS_GETUID", .sysnum = SYS_GETUID, .hndl = GET_SYSCALL_HANDLER(getuid) },
    { .name = "SYS_GETEUID", .sysnum = SYS_GETEUID, .hndl = GET_SYSCALL_HANDLER(geteuid) },
    { .name = "SYS_GETGID", .sysnum = SYS_GETGID, .hndl = GET_SYSCALL_HANDLER(getgid) },
    { .name = "SYS_GETEGID", .sysnum = SYS_GETEGID, .hndl = GET_SYSCALL_HANDLER(getegid) },
    { .name = "SYS_GETHOSTNAME", .sysnum = SYS_GETHOSTNAME, .hndl = GET_SYSCALL_HANDLER(gethostname) },
    { .name = "SYS_SETHOSTNAME", .sysnum = SYS_SETHOSTNAME, .hndl = GET_SYSCALL_HANDLER(sethostname) },
    { .name = "SYS_PROC_INFO", .sysnum = SYS_PROC_INFO, .hndl = GET_SYSCALL_HANDLER(kill) },                /* TODO: IMPLEMENT THIS!!! */
    { .name = "SYS_SENDTASK", .sysnum = SYS_SENDTASK, .hndl = GET_SYSCALL_HANDLER(sendtask) },
    { .name = "SYS_GETTASK", .sysnum = SYS_GETTASK, .hndl = GET_SYSCALL_HANDLER(gettask) },
    { .name = "SYS_SIGNEXEC", .sysnum = SYS_SIGNEXEC, .hndl = GET_SYSCALL_HANDLER(signexec) },
    { .name = "SYS_PROCPATH", .sysnum = SYS_PROCPATH, .hndl = GET_SYSCALL_HANDLER(procpath) },
    { .name = "SYS_PROCBSD", .sysnum = SYS_PROCBSD, .hndl = GET_SYSCALL_HANDLER(procbsd) },
    { .name = "SYS_HANDOFFEP", .sysnum = SYS_HANDOFFEP, .hndl = GET_SYSCALL_HANDLER(handoffep) }
};
