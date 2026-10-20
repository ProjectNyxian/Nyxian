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

#ifndef PATCHCACHE_H
#define PATCHCACHE_H

#include <stdint.h>
#include <mach/kern_return.h>

enum {
    /* for the RO file system sandbox mmap bypass */
    kDyldPtrOpen = 0,
    kDyldPtrFcntl,
    kDyldPtrFstat64,
    kDyldPtrStat64,
    kDyldPtrOpenat,
    
    /* for the dlopen with the lock bypasses */
    kDyldLockUnlockFunc,
    
    /* dyld hook ptrs */
    kDyldNSGetExecutablePathVTFN,
    kDyldProgramSDKAtLeastVTFN,
    kDyldGetProgramSDKVersionVTFN,
    
    kCFBundleMainOffset,
    kCFBundleMainInitedOffset,
    kNSBundleMainOffset,
    
    kDyldPtrCount,
};

kern_return_t ksurface_patchcache_emit(void);

#endif /* PATCHCACHE_H */
