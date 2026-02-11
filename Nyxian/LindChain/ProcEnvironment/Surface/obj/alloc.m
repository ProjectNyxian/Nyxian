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
                           kvobject_handler_t deinit)
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
    kvobject_t *kvo = malloc(size);
    
    /* checking if allocation suceeded */
    if(kvo == NULL)
    {
        return NULL;
    }
    
    /* setting up kvobject for usage */
    kvo->size = sizeof(size);                   /* noting size down */
    kvo->refcount = 1;                          /* starting as retained for the caller, cuz the caller gets one reference */
    kvo->invalid = false;                       /* the kvobject is not useless obviously, its about to be born */
    pthread_rwlock_init(&(kvo->rwlock), NULL);  /* initilizing the lock lol */
    kvo->copy_is = false;                       /* its a real object */
    kvo->copy_link = NULL;                      /* not an copy, so no reference to real object */
    kvo->fresh_is = true;
    
    /* setting handlers and running init straight */
    kvo->init = init;
    kvo->deinit = deinit;
    
    /* checking init handler and executing if nonnull */
    if(kvo->init != NULL)
    {
        kvo->init(kvo);
    }
    
    /* returning da object */
    return kvo;
}

kvobject_t *kvobject_dup(kvobject_t *kvo)
{
    /* sanity check */
    if(kvo == NULL ||
       kvobject_retain(kvo) != kSurfaceReturnSuccess)
    {
        return NULL;
    }
    
    kvobject_wrlock(kvo);
    
    /* creating new object */
    kvobject_t *kvo_dup = malloc(kvo->size);
    
    /* checking if allocation was successful */
    if(kvo_dup == NULL)
    {
        goto out_unlock;
    }
    
    /* copying object over */
    memcpy(kvo_dup, kvo, kvo->size);
    kvo_dup->refcount = 1;                          /* starting as retained for the caller, cuz the caller gets one reference */
    kvo_dup->invalid = false;                       /* the kvobject is not useless obviously, its about to be born */
    pthread_rwlock_init(&(kvo_dup->rwlock), NULL);  /* initilizing the lock lol */
    
    /* checking if */
    
    /* checking init handler and executing if nonnull */
    if(kvo->init != NULL)
    {
        kvo->init(kvo);
    }
    
out_unlock:
    kvobject_unlock(kvo);
    kvobject_release(kvo);
    return kvo_dup;
}
