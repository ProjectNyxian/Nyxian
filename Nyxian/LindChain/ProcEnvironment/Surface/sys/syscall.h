/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2025 - 2026 emexlab

 This file is part of Nyxian.

 Licensed under the emexLabs Public Source License, version 1.1
 (EPSL 1.1).

 Private use and modification are permitted under the license.
 Redistribution of source or binaries, modified or unmodified,
 requires prior written permission from emexLabs.

 External deployment is subject to the source-availability
 requirements and other conditions of the license.

 Provided "AS IS", without warranty, to the extent permitted by law.

 See LICENSE for the full license terms.
*/

#ifndef SURFACE_SYS_SYSCALL_H
#define SURFACE_SYS_SYSCALL_H

/* system headers */
#include <sys/syscall.h>

/* headers to all syscall handlers */
#include <LindChain/ProcEnvironment/Surface/sys/host/ioctl.h>
#include <LindChain/ProcEnvironment/Surface/sys/host/sysctl.h>
#include <LindChain/ProcEnvironment/Surface/sys/host/openpty.h>
#include <LindChain/ProcEnvironment/Surface/sys/compat/task_for_pid.h>
#include <LindChain/ProcEnvironment/Surface/sys/compat/handoffep.h>
#include <LindChain/ProcEnvironment/Surface/sys/compat/waittask.h>
#include <LindChain/ProcEnvironment/Surface/sys/compat/pectl.h>
#include <LindChain/ProcEnvironment/Surface/sys/compat/sign.h>
#include <LindChain/ProcEnvironment/Surface/sys/compat/vroot.h>
#include <LindChain/ProcEnvironment/Surface/sys/cred/setuid.h>
#include <LindChain/ProcEnvironment/Surface/sys/cred/setgid.h>
#include <LindChain/ProcEnvironment/Surface/sys/cred/getppid.h>
#include <LindChain/ProcEnvironment/Surface/sys/cred/getuid.h>
#include <LindChain/ProcEnvironment/Surface/sys/cred/getgid.h>
#include <LindChain/ProcEnvironment/Surface/sys/cred/loginctl.h>
#include <LindChain/ProcEnvironment/Surface/sys/cred/groupctl.h>
#include <LindChain/ProcEnvironment/Surface/sys/cred/getsid.h>
#include <LindChain/ProcEnvironment/Surface/sys/cred/setsid.h>
#include <LindChain/ProcEnvironment/Surface/sys/proc/kill.h>
#include <LindChain/ProcEnvironment/Surface/sys/proc/wait4.h>
#include <LindChain/ProcEnvironment/Surface/sys/proc/proc_info.h>

typedef struct {
    const char *name;
    uint32_t sysnum;
    syscall_handler_t hndl;
} syscall_list_item_t;

#endif /* SURFACE_SYS_SYSCALL_H */
