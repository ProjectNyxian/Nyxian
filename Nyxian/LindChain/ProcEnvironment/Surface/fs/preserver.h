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

#ifndef KSURFACE_FS_PRESERVER_H
#define KSURFACE_FS_PRESERVER_H

#include <mach/kern_return.h>
#include <stdint.h>
#include <limits.h>
#include <stddef.h>

typedef enum: uint8_t {
    kFSNodeTypeSymbolicLink,
    kFSNodeTypeDirectory,
} FSNodeType;

typedef struct {
    FSNodeType type;
    char name[PATH_MAX];
    char target[PATH_MAX];
} FSPreserverNode;

typedef struct {
    FSNodeType type;
    const char *name;
    const char *target;
} FSPreserverDesc;

kern_return_t ksurface_fs_preserver_add_node(FSPreserverNode node);
kern_return_t ksurface_fs_preserver_remove_node(const char *path);

kern_return_t ksurface_fs_preserver_kickstart(void);

#endif /* KSURFACE_FS_PRESERVER_H */
