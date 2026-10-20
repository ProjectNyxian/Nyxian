/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2025 - 2026 emexlab
 Copyright (C) 2026 zipgod24

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

#ifndef PROC_SPAWN_H
#define PROC_SPAWN_H

#include <LindChain/ProcEnvironment/Surface/surface.h>
#import <LindChain/ProcEnvironment/Surface/trust/trust.h>

kern_return_t proc_spawn(ksurface_proc_t *parent, ksurface_proc_t **child, pid_t child_pid, int child_pidv, ksurface_trust_identity_t *identity);
kern_return_t proc_kill(ksurface_proc_t *child, int sig);

kern_return_t proc_reap(ksurface_proc_t *child);
kern_return_t proc_zombify(ksurface_proc_t *child);

kern_return_t proc_state_change(ksurface_proc_t *proc, int64_t status);

#endif /* PROC_SPAWN_H */
