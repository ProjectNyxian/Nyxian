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

#ifndef LIBKERN_KPANIC_H
#define LIBKERN_KPANIC_H

#include <stdint.h>

#define KPANIC_BUF_SIZE (16 * 1024)

struct ksurface_panic_header {
    uint32_t magic;
    uint32_t version;
    uint32_t len;
    uint32_t _pad;
    char body[KPANIC_BUF_SIZE];
};

void kpanic_append(const char *fmt, ...) __printflike(1, 2);

__attribute__((noreturn))
void kpanic(const char *fmt, ...) __printflike(1, 2);

const struct ksurface_panic_header *kpanic_log_get(void);

#endif /* LIBKERN_KPANIC_H */
