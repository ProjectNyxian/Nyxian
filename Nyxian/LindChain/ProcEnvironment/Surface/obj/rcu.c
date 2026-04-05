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

#include <LindChain/ProcEnvironment/Surface/obj/rcu.h>
#include <LindChain/ProcEnvironment/Surface/obj/alloc.h>
#include <LindChain/ProcEnvironment/Surface/obj/reference.h>
#include <assert.h>
#include <stdlib.h>

kvrcuobject_strong_t *kvrcuobject_alloc(kvobject_main_event_handler_t handler)
{
    /* allocating brand new kvobject */
    kvrcuobject_t *kvrcuo = calloc(1, sizeof(kvrcuobject_t));
    
    /* checking if allocation suceeded */
    if(kvrcuo == NULL)
    {
        return NULL;
    }
    
    /* setting up kvobject for usage */
    kvrcuo->header.refcount = 1;                          /* starting as retained for the caller, cuz the caller gets one reference */
    kvrcuo->header.base_type = kvObjBaseTypeObjectRCU;
    kvrcuo->header.state = kvObjStateNormal;
    kvrcuo->header.orig = NULL;
    
    if(pthread_mutex_init(&(kvrcuo->mutex), NULL) != 0)
    {
        free(kvrcuo);
        return NULL;
    }
    
    /* create the normal object */
    kvobject_strong_t *kvo = kvo_alloc(handler);
    if(kvo == NULL)
    {
        pthread_mutex_destroy(&(kvrcuo->mutex));
        free(kvrcuo);
        return NULL;
    }
    
    atomic_store(&(kvrcuo->current), kvo);
    
    return kvrcuo;
}

kvobject_strong_t *kvrcuobject_writer_get_ref(kvrcuobject_strong_t *kvrcuo)
{
    //pthread_mutex_lock(&(kvrcuo->mutex));
    return NULL;
}

kvobject_strong_t *kvrcuobject_reader_get_ref(kvrcuobject_strong_t *kvrcuo)
{
    kvobject_strong_t *kvo = atomic_load_explicit(&(kvrcuo->current), memory_order_acquire);
    /* FIXME: can lead to a UAF, because kvo can become stale */
    if(!kvo_retain(kvo))
    {
        return NULL;
    }
    return kvo;
}

void kvrcuobject_update(kvrcuobject_strong_t *kvrcuo,
                        kvobject_strong_t *kvo)
{
    kvobject_strong_t *current_kvo = atomic_load_explicit(&(kvrcuo->current), memory_order_acquire);
    kvo_release(kvo);
    atomic_store_explicit(&(kvrcuo->current), kvo, memory_order_release);
}
