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
    { .name = "SYS_kill",           .sysnum = SYS_kill,         .hndl = GET_SYSCALL_HANDLER(kill)           },
    { .name = "SYS_bamset",         .sysnum = SYS_bamset,       .hndl = GET_SYSCALL_HANDLER(bamset)         },
    { .name = "SYS_proctb",         .sysnum = SYS_proctb,       .hndl = GET_SYSCALL_HANDLER(proctb)         },
    { .name = "SYS_setuid",         .sysnum = SYS_setuid,       .hndl = GET_SYSCALL_HANDLER(setuid)         },
    { .name = "SYS_seteuid",        .sysnum = SYS_seteuid,      .hndl = GET_SYSCALL_HANDLER(seteuid)        },
    { .name = "SYS_setgid",         .sysnum = SYS_setgid,       .hndl = GET_SYSCALL_HANDLER(setgid)         },
    { .name = "SYS_setegid",        .sysnum = SYS_setegid,      .hndl = GET_SYSCALL_HANDLER(setegid)        },
    { .name = "SYS_setreuid",       .sysnum = SYS_setreuid,     .hndl = GET_SYSCALL_HANDLER(setreuid)       },
    { .name = "SYS_setregid",       .sysnum = SYS_setregid,     .hndl = GET_SYSCALL_HANDLER(setregid)       },
    { .name = "SYS_getent",         .sysnum = SYS_getent,       .hndl = GET_SYSCALL_HANDLER(getent)         },
    { .name = "SYS_getpid",         .sysnum = SYS_getpid,       .hndl = GET_SYSCALL_HANDLER(getpid)         },
    { .name = "sys_getppid",        .sysnum = SYS_getppid,      .hndl = GET_SYSCALL_HANDLER(getppid)        },
    { .name = "SYS_getuid",         .sysnum = SYS_getuid,       .hndl = GET_SYSCALL_HANDLER(getuid)         },
    { .name = "SYS_geteuid",        .sysnum = SYS_geteuid,      .hndl = GET_SYSCALL_HANDLER(geteuid)        },
    { .name = "SYS_getgid",         .sysnum = SYS_getgid,       .hndl = GET_SYSCALL_HANDLER(getgid)         },
    { .name = "SYS_getegid",        .sysnum = SYS_getegid,      .hndl = GET_SYSCALL_HANDLER(getegid)        },
    { .name = "SYS_gethostname",    .sysnum = SYS_gethostname,  .hndl = GET_SYSCALL_HANDLER(gethostname)    },
    { .name = "SYS_sethostname",    .sysnum = SYS_sethostname,  .hndl = GET_SYSCALL_HANDLER(sethostname)    },
    { .name = "SYS_gettask",        .sysnum = SYS_gettask,      .hndl = GET_SYSCALL_HANDLER(gettask)        },
    { .name = "SYS_signexec",       .sysnum = SYS_signexec,     .hndl = GET_SYSCALL_HANDLER(signexec)       },
    { .name = "SYS_procpath",       .sysnum = SYS_procpath,     .hndl = GET_SYSCALL_HANDLER(procpath)       },
    { .name = "SYS_procbsd",        .sysnum = SYS_procbsd,      .hndl = GET_SYSCALL_HANDLER(procbsd)        },
    { .name = "SYS_handoffep",      .sysnum = SYS_handoffep,    .hndl = GET_SYSCALL_HANDLER(handoffep)      },
    { .name = "SYS_getsid",         .sysnum = SYS_getsid,       .hndl = GET_SYSCALL_HANDLER(getsid)         },
    { .name = "SYS_setsid",         .sysnum = SYS_setsid,       .hndl = GET_SYSCALL_HANDLER(setsid)         }
};
