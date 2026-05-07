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

#include <LindChain/ProcEnvironment/Surface/sys/syscall.h>
#include <unistd.h>

/* list of syscalls for the kernel virtualization layer lol */
syscall_list_item_t sys_list[SYS_N] = {
    { .name = "SYS_kill",           .sysnum = SYS_kill,         .hndl = GET_SYSCALL_HANDLER(kill)           },
    { .name = "SYS_setuid",         .sysnum = SYS_setuid,       .hndl = GET_SYSCALL_HANDLER(setuid)         },
    { .name = "SYS_seteuid",        .sysnum = SYS_seteuid,      .hndl = GET_SYSCALL_HANDLER(seteuid)        },
    { .name = "SYS_setgid",         .sysnum = SYS_setgid,       .hndl = GET_SYSCALL_HANDLER(setgid)         },
    { .name = "SYS_setegid",        .sysnum = SYS_setegid,      .hndl = GET_SYSCALL_HANDLER(setegid)        },
    { .name = "SYS_setreuid",       .sysnum = SYS_setreuid,     .hndl = GET_SYSCALL_HANDLER(setreuid)       },
    { .name = "SYS_setregid",       .sysnum = SYS_setregid,     .hndl = GET_SYSCALL_HANDLER(setregid)       },
    { .name = "SYS_getent",         .sysnum = SYS_getent,       .hndl = GET_SYSCALL_HANDLER(getent)         },
    { .name = "sys_getppid",        .sysnum = SYS_getppid,      .hndl = GET_SYSCALL_HANDLER(getppid)        },
    { .name = "SYS_getuid",         .sysnum = SYS_getuid,       .hndl = GET_SYSCALL_HANDLER(getuid)         },
    { .name = "SYS_geteuid",        .sysnum = SYS_geteuid,      .hndl = GET_SYSCALL_HANDLER(geteuid)        },
    { .name = "SYS_getgid",         .sysnum = SYS_getgid,       .hndl = GET_SYSCALL_HANDLER(getgid)         },
    { .name = "SYS_getegid",        .sysnum = SYS_getegid,      .hndl = GET_SYSCALL_HANDLER(getegid)        },
    { .name = "SYS_gettask",        .sysnum = SYS_gettask,      .hndl = GET_SYSCALL_HANDLER(gettask)        },
    { .name = "SYS_procpath",       .sysnum = SYS_procpath,     .hndl = GET_SYSCALL_HANDLER(procpath)       },
    { .name = "SYS_handoffep",      .sysnum = SYS_handoffep,    .hndl = GET_SYSCALL_HANDLER(handoffep)      },
    { .name = "SYS_getsid",         .sysnum = SYS_getsid,       .hndl = GET_SYSCALL_HANDLER(getsid)         },
    { .name = "SYS_setsid",         .sysnum = SYS_setsid,       .hndl = GET_SYSCALL_HANDLER(setsid)         },
    { .name = "SYS_sysctl",         .sysnum = SYS_sysctl,       .hndl = GET_SYSCALL_HANDLER(sysctl)         },
    { .name = "SYS_sysctlbyname",   .sysnum = SYS_sysctlbyname, .hndl = GET_SYSCALL_HANDLER(sysctlbyname)   },
    { .name = "SYS_wait4",          .sysnum = SYS_wait4,        .hndl = GET_SYSCALL_HANDLER(wait4)          },
    { .name = "SYS_ioctl",          .sysnum = SYS_ioctl,        .hndl = GET_SYSCALL_HANDLER(ioctl)          },
    { .name = "SYS_setent",         .sysnum = SYS_setent,       .hndl = GET_SYSCALL_HANDLER(setent)         },
    { .name = "SYS_waittask",       .sysnum = SYS_waittask,     .hndl = GET_SYSCALL_HANDLER(waittask)       },
    { .name = "SYS_pectl",          .sysnum = SYS_pectl,        .hndl = GET_SYSCALL_HANDLER(pectl)          },
};
