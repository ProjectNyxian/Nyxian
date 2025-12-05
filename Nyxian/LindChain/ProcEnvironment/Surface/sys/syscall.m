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
    { .name = "SYS_SETEGID", .sysnum = SYS_KILL, .hndl = GET_SYSCALL_HANDLER(setegid) },
    { .name = "SYS_SETREUID", .sysnum = SYS_KILL, .hndl = GET_SYSCALL_HANDLER(setreuid) },
    { .name = "SYS_SETREGID", .sysnum = SYS_KILL, .hndl = GET_SYSCALL_HANDLER(setregid) }
};
