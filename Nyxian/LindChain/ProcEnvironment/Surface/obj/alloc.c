/*
 Copyright (C) 2025 cr4zyengineer

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#import <LindChain/ProcEnvironment/Surface/obj/alloc.h>
#import <LindChain/ProcEnvironment/Surface/obj/reference.h>
#import <LindChain/ProcEnvironment/Surface/obj/lock.h>
#import <LindChain/ProcEnvironment/Surface/obj/event.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

kvobject_strong_t *kvobject_alloc(size_t size,
                                  kvobject_main_event_handler_t handler)
{
    assert(handler != NULL);
    
    /*
     * first we gotta check if the size
     * is atleast the size of an kvobject
     */
    if(size < sizeof(kvobject_t))
    {
        return NULL;
    }
    
    /* allocating brand new kvobject */
    kvobject_t *kvo = calloc(1, size);
    
    /* checking if allocation suceeded */
    if(kvo == NULL)
    {
        return NULL;
    }
    
    /* setting up kvobject for usage */
    kvo->size = size;                           /* noting size down */
    kvo->refcount = 1;                          /* starting as retained for the caller, cuz the caller gets one reference */
    kvo->invalid = false;                       /* the kvobject is not useless obviously, its about to be born */
    pthread_rwlock_init(&(kvo->rwlock), NULL);  /* initilizing the lock lol */
    
    /* setting handlers and running init straight */
    kvo->main_handler = handler;
    
    /* checking init handler and executing if nonnull */
    if(kvo->main_handler != NULL &&
       !kvo->main_handler(&kvo, kvObjEventInit))
    {
        pthread_rwlock_destroy(&(kvo->rwlock));
        free(kvo);
        return NULL;
    }
    
    /* returning da object */
    return kvo;
}

kvobject_strong_t *kvobject_copy(kvobject_t *kvo)
{
    /* sanity check */
    if(!kvo_retain(kvo))
    {
        return NULL;
    }
    
    kvo_wrlock(kvo);
    
    /* creating new object */
    kvobject_t *kvo_dup = calloc(1, kvo->size);
    
    /* checking if allocation was successful */
    if(kvo_dup == NULL)
    {
        goto out_unlock;
    }
    
    /* setup object initially */
    kvo_dup->size = kvo->size;
    kvo_dup->refcount = 1;                                  /* starting as retained for the caller, cuz the caller gets one reference */
    kvo_dup->invalid = false;                               /* the kvobject is not useless obviously, its about to be born */
    pthread_rwlock_init(&(kvo_dup->rwlock), NULL);          /* initilizing the lock lol */
    pthread_rwlock_init(&(kvo_dup->event_rwlock), NULL);    /* initilizing the other lock lol */
    
    /* setting handlers and running copyit straight */
    kvo_dup->main_handler = kvo->main_handler;
    
    /* preparing stack array */
    kvobject_t *kvoarr[2] = { kvo_dup, kvo };
    
    /* checking init handler and executing if nonnull */
    if(kvo_dup->main_handler != NULL &&
       !kvo_dup->main_handler(kvoarr, kvObjEventCopy))
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
