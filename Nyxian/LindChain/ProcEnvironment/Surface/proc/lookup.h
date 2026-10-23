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

#ifndef PROC_LOOKUP_H
#define PROC_LOOKUP_H

#include <LindChain/ProcEnvironment/Surface/surface.h>

kern_return_t proc_for_pid(pid_t pid, ksurface_proc_t **proc);
kern_return_t proc_for_pid_with_pidv(pid_t pid, int pidv, ksurface_proc_t **proc);
kern_return_t proc_task_for_proc(ksurface_proc_t *proc, task_special_port_t *flavour, task_t *task);
kern_return_t proc_task_for_pid(pid_t pid, task_special_port_t *flavour, task_t *task);
kern_return_t proc_parent_for_proc(ksurface_proc_t *child, ksurface_proc_t **parent);
kern_return_t proc_exists_for_pid(pid_t pid);

#endif /* PROC_LOOKUP_H */
