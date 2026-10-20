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

#ifndef HWHOOK_H
#define HWHOOK_H

#include <CoreFoundation/CoreFoundation.h>

typedef struct __HWHook *HWHookRef;

CF_EXPORT CFTypeID HWHookGetTypeID(void);

CF_EXPORT HWHookRef HWHookCreateWithPointerToSymbol(CFAllocatorRef allocator, void *symbol, void *replacement);

CF_EXPORT void *HWHookGetSymbolPtr(HWHookRef hook);
CF_EXPORT void *HWHookGetReplacementPtr(HWHookRef hook);

CF_EXPORT void HWHookSetSymbolPtr(HWHookRef hook, void *symbol);
CF_EXPORT void HWHookSetReplacementPtr(HWHookRef hook, void *replacement);

/*
 * makes you able to call original symbols without manually
 * fiddling around, the hooking server will disable automatically
 * all hooks in the context and add a new stack frame which calls a
 * symbol that reenables all hooks in the context.
 */
CF_EXPORT Boolean HWHookGetDisableContextHooksInFrame(HWHookRef hook);
CF_EXPORT void HWHookSetDisableContextHooksInFrame(HWHookRef hook, Boolean disableContextHooksInFrame);

#endif /* HWHOOK_H */
