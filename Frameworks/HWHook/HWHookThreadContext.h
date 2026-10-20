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

#ifndef HWHOOKTHREADCONTEXT_H
#define HWHOOKTHREADCONTEXT_H

#include <CoreFoundation/CoreFoundation.h>
#include "HWHook.h"

typedef struct __HWHookThreadContext *HWHookThreadContextRef;

CF_EXPORT CFTypeID HWHookThreadContextGetTypeID(void);

/* so you can exit the context easily */
CF_EXPORT HWHookThreadContextRef HWHookThreadContextGetCurrent(void);

/* creates brand new thread context */
CF_EXPORT HWHookThreadContextRef HWHookThreadContextCreate(CFAllocatorRef allocator);

/* enters on a per thread basis */
CF_EXPORT Boolean HWHookThreadContextEnter(HWHookThreadContextRef context);
CF_EXPORT Boolean HWHookThreadContextExit(HWHookThreadContextRef context);

/* disables while being entered */
CF_EXPORT Boolean HWHookThreadContextEnableHooks(HWHookThreadContextRef context);
CF_EXPORT Boolean HWHookThreadContextDisableHooks(HWHookThreadContextRef context);

/*
 * you have to exit the context to call the original
 * other than that this hooks symbols until the context
 * ran out.
 *
 * don't append hooks while a thread entered the context,
 * this will be a future feature tho, altering the context
 * while being in it.
 *
 * Duy Tran, this! THIS is flexibility and scalability!
 */
CF_EXPORT Boolean HWHookThreadContextAppendHook(HWHookThreadContextRef context, HWHookRef hook);
CF_EXPORT CFArrayRef HWHookThreadContextGetHooks(HWHookThreadContextRef context);

#endif /* HWHOOKTHREADCONTEXT_H */
