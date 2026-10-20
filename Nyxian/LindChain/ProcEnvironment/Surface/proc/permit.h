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

#ifndef PROC_PERMIT_H
#define PROC_PERMIT_H

#include <LindChain/ProcEnvironment/Surface/surface.h>
#include <LindChain/ProcEnvironment/Surface/proc/proc.h>

bool proc_snapshot_primitive_over_proc_allowed(ksurface_proc_snapshot_t *proc, ksurface_proc_t *targetProc, PEEntitlementFlags entitlementsNeeded, PEEntitlementFlags targetEntitlementsNeeded, errno_t *err);
bool proc_primitive_over_proc_allowed(ksurface_proc_t *proc, ksurface_proc_t *targetProc, PEEntitlementFlags entitlementsNeeded, PEEntitlementFlags targetEntitlementsNeeded, errno_t *err);
bool proc_pid_primitive_over_pid_allowed(pid_t pid, pid_t targetPid, PEEntitlementFlags entitlementsNeeded, PEEntitlementFlags targetEntitlementsNeeded, errno_t *err);

#endif /* PROC_PERMIT_H */
