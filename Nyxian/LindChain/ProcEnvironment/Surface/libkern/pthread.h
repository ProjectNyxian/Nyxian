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

#ifndef LIBKERN_PTHREAD_H
#define LIBKERN_PTHREAD_H

#include <pthread.h>
#include <mach/mach.h>
#include <errno.h>

static inline int pthread_suspend(pthread_t pthread)
{
    thread_t thread = pthread_mach_thread_np(pthread);
    return thread_suspend(thread) == KERN_SUCCESS ? 0 : EINVAL;
}

static inline int pthread_resume(pthread_t pthread)
{
    thread_t thread = pthread_mach_thread_np(pthread);
    return thread_resume(thread) == KERN_SUCCESS ? 0 : EINVAL;
}

#endif /* LIBKERN_PTHREAD_H */
