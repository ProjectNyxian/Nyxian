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

#import <LindChain/ProcEnvironment/Surface/libkern/kpanic.h>
#import <LindChain/ProcEnvironment/Surface/libkern/obj/reference.h>
#import <LindChain/ProcEnvironment/Surface/libkern/obj/event.h>
#include <stdlib.h>
#include <assert.h>
#include <dlfcn.h>

bool kvobject_retain(kvobject_t *kvo)
{
    assert(kvo != NULL);
    
    if(!kvo->memoryIsOwned)
    {
        kpanic("object with type %d was attempted to retain while unowned", kvo->base_type);
    }
    
    /* performing retain if valid */
    while(1)
    {
        /* getting current reference count */
        int current = atomic_load(&kvo->refcount);
        
        /* checking if object can be retained */
        if(current <= 0 || (atomic_load(&kvo->state) == kvObjStateInvalid))
        {
            return false;
        }
        
        /* retaining object */
        if(atomic_compare_exchange_weak(&kvo->refcount, &current, current + 1))
        {
            /* performing another check */
            if(atomic_load(&kvo->state) == kvObjStateInvalid)
            {
                /* rollback using release logic */
                kvo_release(kvo);
                return false;
            }
            
            return true;
        }
    }
}

void kvobject_invalidate(kvobject_t *kvo)
{
    assert(kvo != NULL);
    kvo_event_trigger(kvo, kvObjEventInvalidate, 0);
    atomic_store(&(kvo->state), kvObjStateInvalid);
}

void kvobject_release(kvobject_t *kvo)
{
    assert(kvo != NULL);
    
    /* releasing and trying to get the old reference count */
    int old = atomic_fetch_sub(&kvo->refcount, 1);
    if(old == 1)
    {
        kvobject_event_trigger(kvo, kvObjEventDeinit, 0);
        
        /* only a normal object has these locks */
        switch(kvo->base_type)
        {
            case kvObjBaseTypeObject:
                pthread_rwlock_destroy(&(kvo->rwlock));
                pthread_rwlock_destroy(&(kvo->event_rwlock));
                break;
            case kvObjBaseTypeObjectSnapshot:
                if(kvo->orig != NULL)
                {
                    kvo_release(kvo->orig);
                }
                break;
            default:
                kpanic("unknown object %d type got deinitilized", kvo->base_type);
                break;
        }
        
        if(kvo->memoryIsOwned)
        {
            free(kvo);
        }
    }
    else if(old <= 0)
    {
        Dl_info info;
        dladdr(kvo->main_handler, &info);
        
        /*
         * happens on reference underflow, by design a
         * panic cuz this never happens legitimately
         */
        kpanic("reference underflow on kvobject @ %p with main event handler @ %p (%s)", kvo, info.dli_fbase, info.dli_fname);
    }
}
