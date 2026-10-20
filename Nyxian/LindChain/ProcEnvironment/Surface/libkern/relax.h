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

#ifndef LIBKERN_EXTRA_H
#define LIBKERN_EXTRA_H

/*!
 @function relax
 @abstract Tells the CPU to relax and shut up XD.
 */
static inline void relax(void)
{
#if defined(__x86_64__) || defined(__i386__)
    __asm__ volatile("pause");
#elif defined(__aarch64__)
    __asm__ volatile("yield");
#else
    #error "no relaxiation is very wasteful, I won't compile till you fixed me. >:3"
    // fallback: nothing
#endif
}

#endif /* LIBKERN_EXTRA_H */
