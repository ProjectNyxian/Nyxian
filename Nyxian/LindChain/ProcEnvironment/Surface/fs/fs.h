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

#ifndef FS_FS_H
#define FS_FS_H

#include <sys/syslimits.h>
#include <mach/kern_return.h>
#include <stdbool.h>
#include <stdint.h>

extern NSString *kextFSRoot;

kern_return_t ksurface_fs_init(void);

kern_return_t ksurface_fs_install_kext_at_path(const char *path);

#endif /* FS_FS_H */
