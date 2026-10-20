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

#ifndef SURFACE_SYS_SETUID_H
#define SURFACE_SYS_SETUID_H

#include <LindChain/ProcEnvironment/Surface/surface.h>

typedef struct {
    uid_t ruid;
    uid_t euid;
    uid_t svuid;
    gid_t rgid;
    gid_t egid;
    gid_t svgid;
} ksurface_proc_ucred_backup_t;

ksurface_proc_ucred_backup_t proc_make_ucred_backup(ksurface_proc_t *proc);
void proc_set_sugid_if_applicable(ksurface_proc_t *proc, ksurface_proc_ucred_backup_t backup);

bool proc_is_privileged(ksurface_proc_t *proc);

DEFINE_SYSCALL_HANDLER(setuid);
DEFINE_SYSCALL_HANDLER(seteuid);
DEFINE_SYSCALL_HANDLER(setreuid);

#endif /* SURFACE_SYS_SETUID_H */
