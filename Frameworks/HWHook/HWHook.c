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

#include "CFRuntime.h"
#include "HWHook.h"

static CFTypeID gHWHookTypeID = _kCFRuntimeNotATypeID;

struct __HWHook {
    CFRuntimeBase _base;
    void *symbol;
    void *replacement;
    Boolean disableContextHooksInFrame;
    Boolean disableHookInFrame;
};

static const CFRuntimeClass gHWHook = {
    0,                              /* version */
    "HWHook",                       /* class name */
    NULL,                           /* init */
    NULL,                           /* copy */
    NULL,                           /* finalize */
    NULL,                           /* equal */
    NULL,                           /* hash */
    NULL,                           /* copyFormattingDesc */
    NULL,                           /* copyDebugDesc */
    NULL,
    NULL,
    0
};

CFTypeID HWHookGetTypeID(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gHWHookTypeID = _CFRuntimeRegisterClass(&gHWHook);
    });
    return gHWHookTypeID;
}

HWHookRef HWHookCreateWithPointerToSymbol(CFAllocatorRef allocator,
                                          void *symbol,
                                          void *replacement)
{
    HWHookRef hook = (HWHookRef)_CFRuntimeCreateInstance(allocator, HWHookGetTypeID(), sizeof(struct __HWHook) - sizeof(CFRuntimeBase), NULL);
    if(hook == NULL)
    {
        return NULL;
    }
    
    hook->symbol = symbol;
    hook->replacement = replacement;
    hook->disableContextHooksInFrame = false;
    
    return hook;
}

void *HWHookGetSymbolPtr(HWHookRef hook)
{
    if(hook == NULL)
    {
        return NULL;
    }
    return hook->symbol;
}

void *HWHookGetReplacementPtr(HWHookRef hook)
{
    if(hook == NULL)
    {
        return NULL;
    }
    return hook->replacement;
}

void HWHookSetSymbolPtr(HWHookRef hook,
                        void *symbol)
{
    if(hook == NULL)
    {
        return;
    }
    hook->symbol = symbol;
}

void HWHookSetReplacementPtr(HWHookRef hook,
                             void *replacement)
{
    if(hook == NULL)
    {
        return;
    }
    hook->replacement = replacement;
}

Boolean HWHookGetDisableContextHooksInFrame(HWHookRef hook)
{
    if(hook == NULL)
    {
        return false;
    }
    return hook->disableContextHooksInFrame;
}

void HWHookSetDisableContextHooksInFrame(HWHookRef hook,
                                         Boolean disableContextHooksInFrame)
{
    if(hook == NULL)
    {
        return;
    }
    hook->disableContextHooksInFrame = disableContextHooksInFrame;
}
