/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 cr4zyengineer

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

#ifndef SURFACE_SYS_SYSCALL_H
#define SURFACE_SYS_SYSCALL_H

/* headers to syscall handlers*/
#include <LindChain/ProcEnvironment/Surface/sys/proc/kill.h>
#include <LindChain/ProcEnvironment/Surface/sys/cred/setuid.h>
#include <LindChain/ProcEnvironment/Surface/sys/cred/setgid.h>
#include <LindChain/ProcEnvironment/Surface/sys/compat/getent.h>
#include <LindChain/ProcEnvironment/Surface/sys/cred/getpid.h>
#include <LindChain/ProcEnvironment/Surface/sys/cred/getuid.h>
#include <LindChain/ProcEnvironment/Surface/sys/cred/getgid.h>
#include <LindChain/ProcEnvironment/Surface/sys/compat/gettask.h>
#include <LindChain/ProcEnvironment/Surface/sys/compat/signexec.h>
#include <LindChain/ProcEnvironment/Surface/sys/compat/procpath.h>
#include <LindChain/ProcEnvironment/Surface/sys/compat/handoffep.h>
#include <LindChain/ProcEnvironment/Surface/sys/cred/getsid.h>
#include <LindChain/ProcEnvironment/Surface/sys/cred/setsid.h>
#include <LindChain/ProcEnvironment/Surface/sys/host/sysctl.h>
#include <LindChain/ProcEnvironment/Surface/sys/proc/wait4.h>
#include <LindChain/ProcEnvironment/Surface/sys/proc/exit.h>
#include <LindChain/ProcEnvironment/Surface/sys/host/ioctl.h>
#include <LindChain/ProcEnvironment/Surface/sys/compat/setent.h>
#include <LindChain/ProcEnvironment/Surface/sys/compat/waittask.h>
#include <LindChain/ProcEnvironment/Surface/sys/compat/pectl.h>
#include <LindChain/ProcEnvironment/Surface/sys/compat/getpk.h>
#include <sys/syscall.h>

/* additional nyxian syscalls for now */
#define SYS_proctb      750         /* MARK: deprecated.. use SYS_sysctl instead */
#define SYS_getent      751         /* getting processes entitlements */
#define SYS_gethostname 752         /* MARK: deprecated.. use SYS_sysctl instead */
#define SYS_sethostname 753         /* MARK: deprecated.. use SYS_sysctl instead */
#define SYS_gettask     754         /* gets task port */
#define SYS_signexec    755         /* uses file descriptor passed by guest to sign executable */
#define SYS_procpath    756         /* gets process path of a pid */
#define SYS_procbsd     757         /* MARK: deprecated.. use SYS_sysctl instead */
#define SYS_handoffep   758         /* handoff exception port to kvirt */
#define SYS_setent      759         /* sets entitlements (sanitized ofc) */
#define SYS_waittask    760         /* waits till task port of a task is available */
#define SYS_pectl       761         /* utility for many proc environment operations */
#define SYS_getpk       762         /* copy out the public signature key */

#define SYS_N 29

typedef struct {
    const char *name;
    uint32_t sysnum;
    syscall_handler_t hndl;
} syscall_list_item_t;

extern syscall_list_item_t sys_list[SYS_N];

#endif /* SURFACE_SYS_SYSCALL_H */
