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

#ifndef CFTOOLS_H
#define CFTOOLS_H

#include <stdint.h>
#include <CoreFoundation/CoreFoundation.h>
#include <LindChain/Private/CoreFoundation/CFRuntime.h>

#define cfheader_size() sizeof(CFRuntimeBase)

typedef enum {
    __CFBundleUnknownBinary,
    __CFBundleCFMBinary,
    __CFBundleDYLDExecutableBinary,
    __CFBundleDYLDBundleBinary,
    __CFBundleDYLDFrameworkBinary,
    __CFBundleDLLBinary,
    __CFBundleUnreadableBinary,
    __CFBundleNoBinary,
    __CFBundleELFBinary
} __CFPBinaryType;

Boolean CFSwap(CFTypeRef ref1, CFTypeRef ref2);

void CFBundleSetBinaryType(CFBundleRef bundle, __CFPBinaryType type);
__CFPBinaryType CFBundleGetBinaryType(CFBundleRef bundle);

#endif /* CFTOOLS_H */
