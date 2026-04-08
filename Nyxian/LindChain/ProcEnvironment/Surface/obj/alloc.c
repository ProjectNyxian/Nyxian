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

#import <LindChain/ProcEnvironment/Surface/obj/alloc.h>
#import <LindChain/ProcEnvironment/Surface/obj/reference.h>
#import <LindChain/ProcEnvironment/Surface/obj/lock.h>
#import <LindChain/ProcEnvironment/Surface/obj/event.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

kvobject_strong_t *kvobject_alloc(kvobject_main_event_handler_t handler)
{
    assert(handler != NULL);
    
    /* get object size first */
    size_t size = (size_t)handler(NULL, kvObjEventInit);
    
    /*
     * first we gotta check if the size
     * is atleast the size of an kvobject
     */
    assert(size >= sizeof(kvobject_t));
    
    /* allocating brand new kvobject */
    kvobject_t *kvo = calloc(1, size);
    
    /* checking if allocation suceeded */
    if(kvo == NULL)
    {
        return NULL;
    }
    
    /* setting up kvobject for usage */
    kvo->refcount = 1;                          /* starting as retained for the caller, cuz the caller gets one reference */
    kvo->base_type = kvObjBaseTypeObject;
    kvo->state = kvObjStateNormal;
    kvo->orig = NULL;
    
    /* setting handlers and running init straight */
    kvo->main_handler = handler;
    
    /* safely initilizing both locks */
    if(pthread_rwlock_init(&(kvo->rwlock), NULL) != 0)
    {
        free(kvo);
    }
    
    if(pthread_rwlock_init(&(kvo->event_rwlock), NULL) != 0)
    {
        pthread_rwlock_destroy(&(kvo->rwlock));
        free(kvo);
        return NULL;
    }
    
    /* checking init handler and executing if nonnull */
    if(kvo->main_handler(&kvo, kvObjEventInit) != 0)
    {
        pthread_rwlock_destroy(&(kvo->rwlock));
        pthread_rwlock_destroy(&(kvo->event_rwlock));
        free(kvo);
        return NULL;
    }
    
    /* returning da object */
    return kvo;
}

kvobject_strong_t *kvobject_copy(kvobject_t *kvo)
{
    assert(kvo != NULL);
    
    /* sanity check */
    if(!kvo_retain(kvo))
    {
        return NULL;
    }
    
    kvo_rdlock(kvo);
    
    assert(kvo->base_type == kvObjBaseTypeObject && kvo->main_handler != NULL);
    
    /* getting object size */
    size_t size = (size_t)kvo->main_handler(NULL, kvObjEventInit);
    
    /* creating new object */
    kvobject_t *kvo_dup = calloc(1, size);
    
    /* checking if allocation was successful */
    if(kvo_dup == NULL)
    {
        goto out_unlock;
    }
    
    /* setup object initially */
    kvo_dup->refcount = 1;                                  /* starting as retained for the caller, cuz the caller gets one reference */
    kvo_dup->base_type = kvObjBaseTypeObject;
    kvo_dup->state = kvObjStateNormal;
    kvo_dup->orig = NULL;
    
    /* setting handlers and running copyit straight */
    kvo_dup->main_handler = kvo->main_handler;
    
    /* preparing stack array */
    kvobject_t *kvoarr[2] = { kvo_dup, kvo };
    
    /* safely initilizing both locks */
    if(pthread_rwlock_init(&(kvo_dup->rwlock), NULL) != 0)
    {
        free(kvo_dup);
    }
    
    if(pthread_rwlock_init(&(kvo_dup->event_rwlock), NULL) != 0)
    {
        pthread_rwlock_destroy(&(kvo_dup->rwlock));
        free(kvo_dup);
        kvo_dup = NULL;
        goto out_unlock;
    }
    
    /* checking init handler and executing if nonnull */
    if(kvo_dup->main_handler(kvoarr, kvObjEventCopy) != 0)
    {
        pthread_rwlock_destroy(&(kvo_dup->rwlock));
        pthread_rwlock_destroy(&(kvo_dup->event_rwlock));
        free(kvo_dup);
        kvo_dup = NULL;
    }
    
out_unlock:
    kvo_unlock(kvo);
    kvo_release(kvo);
    return kvo_dup;
}

kvobject_snapshot_t *kvobject_snapshot(kvobject_t *kvo,
                                       kvobject_snapshot_options_t option)
{
    assert(kvo != NULL);
    
    if(!kvo_retain(kvo))
    {
        return NULL;
    }
    
    kvo_rdlock(kvo);
    
    assert(kvo->base_type == kvObjBaseTypeObject && kvo->main_handler != NULL);
    
    /* getting object size */
    size_t size = (size_t)kvo->main_handler(NULL, kvObjEventInit);
    
    /* creating new snapshot object */
    kvobject_t *kvo_snap = calloc(1, size);
    
    /* checking if allocation was successful */
    if(kvo_snap == NULL)
    {
        goto out_unlock;
    }
    
    /* setup object initially */
    kvo_snap->refcount = 1;                                 /* starting as retained for the caller, cuz the caller gets one reference */
    kvo_snap->base_type = kvObjBaseTypeObjectSnapshot;
    kvo_snap->state = kvObjStateNormal;
    
    /* set orig pointer if applicable */
    if(option == kvObjSnapReferenced ||
       option == kvObjSnapConsumeReference)
    {
        kvo_snap->orig = kvo;
    }
    
    /* setting handlers and running copyit straight */
    kvo_snap->main_handler = kvo->main_handler;
    
    /* preparing stack array */
    kvobject_t *kvoarr[2] = { kvo_snap, kvo };
    
    /* checking init handler and executing if nonnull */
    if(kvo_snap->main_handler(kvoarr, kvObjEventSnapshot) != 0)
    {
        free(kvo_snap);
        kvo_snap = NULL;
    }
    
out_unlock:
    kvo_unlock(kvo);
    
    /* release object if applicable */
    if(option == kvObjSnapStatic ||
       option == kvObjSnapConsumeReference)
    {
        kvo_release(kvo);
    }
    
    return kvo_snap;
}
