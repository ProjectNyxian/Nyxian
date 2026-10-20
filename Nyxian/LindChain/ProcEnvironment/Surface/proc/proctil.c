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

#include <LindChain/ProcEnvironment/Surface/libkern/kpanic.h>
#include <LindChain/ProcEnvironment/Surface/proc/proctil.h>
#include <LindChain/ProcEnvironment/Surface/surface.h>
#include <stdatomic.h>
#include <os/lock.h>

static _Atomic uint32_t counter = 1;    /* kernel_proc_ is already one process */
static os_unfair_lock lock = OS_UNFAIR_LOCK_INIT;

kern_return_t proctil(ProctilAction action)
{
    switch(action)
    {
        case kProctilActionCount:
        {
            uint32_t cur = atomic_load_explicit(&counter, memory_order_relaxed);
            do
            {
                if(cur >= PROC_MAX)
                {
                    return KERN_POLICY_LIMIT;
                }
            }
            while(!atomic_compare_exchange_weak_explicit(&counter, &cur, cur + 1, memory_order_acq_rel, memory_order_relaxed));
            return KERN_SUCCESS;
        }
        case kProctilActionUncount:
        {
            uint32_t cur = atomic_load_explicit(&counter, memory_order_relaxed);
            do
            {
                if(cur == 0)
                {
                    kpanic("process count did underflow");
                }
            }
            while(!atomic_compare_exchange_weak_explicit(&counter, &cur, cur - 1, memory_order_release, memory_order_relaxed));
            return KERN_SUCCESS;
        }
        case kProctilActionLock:
            os_unfair_lock_lock(&lock);
            return KERN_SUCCESS;
        case kProctilActionUnlock:
            os_unfair_lock_unlock(&lock);
            return KERN_SUCCESS;
        case kProctilActionTrylock:
            return os_unfair_lock_trylock(&lock) ? KERN_SUCCESS : KERN_FAILURE;
        default:
            return KERN_INVALID_ARGUMENT;
    }
}

