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

#include <LindChain/Utils/CFTools.h>
#include <assert.h>
#include <malloc/malloc.h>

Boolean CFSwap(CFTypeRef ref1,
               CFTypeRef ref2)
{
    if(ref1 == NULL || ref2 == NULL || CFGetTypeID(ref1) != CFGetTypeID(ref2))
    {
        return false;
    }
    
    /*
     * CFRuntimeBase = isa (8) + refcount/flags (8) = 16 bytes
     * skip it... preserve identity (pointer) and retain count
     *
     * lol it is just malloc memory :3
     */
    size_t len = malloc_size(ref1);
    if(len != malloc_size(ref2))
    {
        return false;
    }
    
    /* lets do the magic */
    UInt8 buffer[len];
    memcpy(buffer + cfheader_size(), (UInt8*)ref1 + cfheader_size(), len - cfheader_size());
    memcpy((UInt8*)ref1 + cfheader_size(), (UInt8*)ref2 + cfheader_size(), len - cfheader_size());
    memcpy((UInt8*)ref2 + cfheader_size(), buffer + cfheader_size(), len - cfheader_size());
    return true;
}

static inline CFIndex __CFBundleGetBinaryTypeOffset(CFBundleRef hostBundle)
{
    static CFIndex discoveredOffset = -1;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        uint32_t *ptr = (uint32_t *)hostBundle;
        for(CFIndex i = 4; i < 30; i++)
        {
            if(ptr[i] == __CFBundleDYLDExecutableBinary || ptr[i] == __CFBundleDYLDFrameworkBinary)
            {
                discoveredOffset = i * sizeof(uint32_t);
                return;
            }
        }
    });
    return discoveredOffset;
}

void CFBundleSetBinaryType(CFBundleRef bundle,
                           __CFPBinaryType type)
{
    if(bundle == NULL)
    {
        return;
    }
    
    CFIndex offset = __CFBundleGetBinaryTypeOffset(bundle);
    if(offset < 0)
    {
        return;
    }
    
    ((UInt8*)bundle)[offset] = (UInt8)type;
}

__CFPBinaryType CFBundleGetBinaryType(CFBundleRef bundle)
{
    if(bundle == NULL)
    {
        return __CFBundleUnknownBinary;
    }
    
    CFIndex offset = __CFBundleGetBinaryTypeOffset(bundle);
    if(offset < 0)
    {
        return __CFBundleUnknownBinary;
    }
    
    return (__CFPBinaryType)((UInt8*)bundle)[offset];
}
