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
#include <stdlib.h>
#include <string.h>

kvobject_t *kvobject_alloc(size_t size,
                           kvobject_handler_t init,
                           kvobject_handler_t deinit,
                           kvobject_duo_handler_t copyit)
{
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
    kvo->init = init;
    kvo->deinit = deinit;
    kvo->copyit = copyit;
    
    /* checking init handler and executing if nonnull */
    if(kvo->init != NULL)
    {
        kvo->init(kvo);
    }
    
    /* returning da object */
    return kvo;
}

kvobject_t *kvobject_copy(kvobject_t *kvo)
{
    /* sanity check */
    if(kvo == NULL ||
       !kvobject_retain(kvo))
    {
        return NULL;
    }
    
    kvobject_wrlock(kvo);
    
    /* creating new object */
    kvobject_t *kvo_dup = calloc(1, kvo->size);
    
    /* checking if allocation was successful */
    if(kvo_dup == NULL)
    {
        goto out_unlock;
    }
    
    /* setup object initially */
    kvo_dup->size = kvo->size;
    kvo_dup->refcount = 1;                          /* starting as retained for the caller, cuz the caller gets one reference */
    kvo_dup->invalid = false;                       /* the kvobject is not useless obviously, its about to be born */
    pthread_rwlock_init(&(kvo_dup->rwlock), NULL);  /* initilizing the lock lol */
    
    /* setting handlers and running copyit straight */
    kvo_dup->init = kvo->init;
    kvo_dup->deinit = kvo->deinit;
    kvo_dup->copyit = kvo->copyit;
    
    /* checking init handler and executing if nonnull */
    if(kvo_dup->copyit != NULL)
    {
        kvo_dup->copyit(kvo_dup, kvo);
    }
    
out_unlock:
    kvobject_unlock(kvo);
    kvobject_release(kvo);
    return kvo_dup;
}
