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

#ifndef LIBKERN_KXLD_KXOPEN_H
#define LIBKERN_KXLD_KXOPEN_H

#include <LindChain/ProcEnvironment/Surface/libkern/kxld/image.h>
#include <stdio.h>

#define KXLD_DEFAULT        0
#define KXLD_NOCLOSE        (1ull << 1)
#define KXLD_MAP_PRIVATE    (1ull << 2) /* maps the kext entirely as a private executable */

kern_return_t kxopen(const char *path, int mode, kxld_image_info_t **image_info);
kern_return_t kxopen_with_fd(int fd, int mode, kxld_image_info_t **image_info);
kern_return_t kxclose(kxld_image_info_t *image_info);

kern_return_t kxld_seal(void);

#endif /* LIBKERN_KXLD_KXOPEN_H */
