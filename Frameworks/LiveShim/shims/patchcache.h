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

#ifndef LIVESHIM_PTRCACHE_H
#define LIVESHIM_PTRCACHE_H

#include <stdbool.h>
#include <stdint.h>

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

extern uint64_t patchcache[kDyldPtrCount];

bool ksurface_user_patchcache_load(void);

#endif /* LIVESHIM_PTRCACHE_H */
