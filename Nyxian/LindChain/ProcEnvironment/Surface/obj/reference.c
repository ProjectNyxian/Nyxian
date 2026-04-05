/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 cr4zyengineer

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#import <LindChain/ProcEnvironment/Surface/obj/reference.h>
#import <LindChain/ProcEnvironment/Surface/obj/event.h>
#import <LindChain/ProcEnvironment/panic.h>
#include <stdlib.h>
#include <assert.h>
#include <dlfcn.h>

bool kvobject_retain(kvobject_t *kvo)
{
    assert(kvo != NULL);
    
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

void kvobject_invalidate(kvobject_strong_t *kvo)
{
    assert(kvo != NULL);
    kvo_event_trigger(kvo, kvObjEventInvalidate, 0);
    atomic_store(&(kvo->state), kvObjStateInvalid);
}


void kvobject_release(kvobject_strong_t *kvo)
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
                kvo_release(kvo->orig);
                break;
            case kvObjBaseTypeObjectRCU:
                kvo_invalidate(kvo);
                kvrcuobject_strong_t *kvrcuo = (kvrcuobject_strong_t*)kvo;
                /* TODO: cleanup is missing for now */
                (void)kvrcuo->current;
                (void)kvrcuo->mutex;
                (void)kvrcuo->header;
                /* fallthrough */
            default:
                break;
        }
        
        free(kvo);
    }
    else if(old <= 0)
    {
#if DEBUG
        Dl_info info;
        dladdr(kvo->main_handler, &info);
        
        /*
         * happens on reference underflow, by design a
         * panic cuz this never happens legitimately
         */
        environment_panic("reference underflow on kvobject @ %p with main event handler @ %p (%s)", kvo, info.dli_fbase, info.dli_fname);
#else
        environment_panic("reference underflow on kvobject @ %p", kvo);
#endif /* DEBUG */
    }
}
