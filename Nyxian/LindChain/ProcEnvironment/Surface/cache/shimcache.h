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

#ifndef SHIMCACHE_H
#define SHIMCACHE_H

#include <mach/mach.h>
#include <CoreFoundation/CoreFoundation.h>

typedef CF_ENUM(UInt8, CCFileType) {
    kCCFileTypeC = 0,
    kCCFileTypeCHeader,
    kCCFileTypeCXX,
    kCCFileTypeCXXHeader,
    kCCFileTypeObjC,
    kCCFileTypeObjCHeader,
    kCCFileTypeObjCXX,
    kCCFileTypeObjCXXHeader,
    kCCFileTypeSwift,
    kCCFileTypeObject,
    kCCFileTypeUnknown,
};

typedef struct {
    CCFileType fileType;
    char *code;
} shimcache_segment_t;

kern_return_t ksurface_shimcache_append_code(CCFileType fileType, const char *code);
kern_return_t ksurface_shimcache_build(void);

#endif /* SHIMCACHE_H */
