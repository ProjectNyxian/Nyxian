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

#ifndef PROCENVIRONMENT_FORK_H
#define PROCENVIRONMENT_FORK_H

/* ----------------------------------------------------------------------
 *  Apple API Headers
 * -------------------------------------------------------------------- */
#include <stdlib.h>
#include <spawn.h>

/*!
 @function `environment_fork_init`
 @abstract Initializes fork environment.
 @discussion
    Fixes vfork() and exec*() family symbols using a creative thread snapshotting and conditioning system.
 */
void environment_vfork_init(void);

#endif /* PROCENVIRONMENT_FORK_H */
