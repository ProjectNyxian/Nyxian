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

#import <LindChain/ProcEnvironment/Surface/obj/event.h>
#import <LindChain/ProcEnvironment/Surface/obj/reference.h>
#import <LindChain/ProcEnvironment/Surface/lock.h>
#import <stdlib.h>
#import <assert.h>

ksurface_return_t kvobject_event_register(kvobject_strong_t *kvo,
                                          kvobject_event_type_t mask,
                                          kvobject_event_handler_t handler,
                                          void *context,
                                          kvobject_event_t **event)
{
    assert(kvo != NULL && handler != NULL && kvo->base_type != kvObjBaseTypeObjectSnapshot);
    
    PTHREAD_RWLOCK_DEBUG_IMP_WRLOCK(&(kvo->event_rwlock));
    
    /* find last event */
    if(kvo->event_count >= KVOBJECT_EVENT_MAX)
    {
        PTHREAD_RWLOCK_DEBUG_IMP_UNLOCK(&(kvo->event_rwlock));
        return SURFACE_LIMIT;
    }
    
    /* allocating new event */
    kvobject_event_t *e_event = malloc(sizeof(kvobject_event_t));
    
    if(e_event == NULL)
    {
        PTHREAD_RWLOCK_DEBUG_IMP_UNLOCK(&(kvo->event_rwlock));
        return SURFACE_NOMEM;
    }
    
    /* setting mutex */
    if(pthread_mutex_init(&(e_event->in_use), NULL) != 0)
    {
        PTHREAD_RWLOCK_DEBUG_IMP_UNLOCK(&(kvo->event_rwlock));
        free(e_event);
        return SURFACE_FAILED;
    }
    
    /* setting properties */
    e_event->previous = NULL;
    e_event->next = kvo->event;
    e_event->owner = kvo;
    e_event->handler = handler;
    e_event->ctx = context;
    e_event->mask = mask;
    
    /* now insert new event as the first event (faster) */
    if(kvo->event != NULL)
    {
        kvo->event->previous = e_event;
    }
    kvo->event = e_event;
    kvo->event_count++;
    
    PTHREAD_RWLOCK_DEBUG_IMP_UNLOCK(&(kvo->event_rwlock));
    
    /* if event back pointer is givven, set it */
    if(event != NULL)
    {
        *event = e_event;
    }
    
    return SURFACE_SUCCESS;
}

void kvobject_event_trigger(kvobject_strong_t *kvo,
                            kvobject_event_type_t type,
                            uint64_t value)
{
    assert(kvo != NULL && type != kvObjEventCopy && type != kvObjEventUnregister);
    
    /* sanity checking object type */
    if(kvo->base_type != kvObjBaseTypeObject)
    {
        return;
    }
    
    /* the main event handler shall always be called */
    kvo->main_handler(&kvo, type);
    
    PTHREAD_RWLOCK_DEBUG_IMP_WRLOCK(&(kvo->event_rwlock));
    
    /*
     * execute all events in the chain and remove
     * events that wanna be removed(return true).
     */
    kvobject_event_t *last_event = kvo->event;
    while(last_event != NULL)
    {
        /* pointer to current event */
        kvobject_event_t *current = last_event;
        last_event = current->next;
        
        if(type != kvObjEventDeinit && (current->mask & type) != type)
        {
            continue;
        }
        
        if(pthread_mutex_trylock(&(current->in_use)) != 0)
        {
            continue;
        }
        
        /* unlocking again to allow recurse */
        PTHREAD_RWLOCK_DEBUG_IMP_UNLOCK(&(kvo->event_rwlock));
        bool will_remove = current->handler(type, value, current);
        PTHREAD_RWLOCK_DEBUG_IMP_WRLOCK(&(kvo->event_rwlock));
        
        pthread_mutex_unlock(&(current->in_use));
        
        /* remove if applicable */
        if(will_remove || type == kvObjEventDeinit)
        {
            /* triggering unregistration event */
            current->handler(kvObjEventUnregister, 0, current);
            
            /* relinking previous and next */
            if(current->next != NULL)
            {
                current->next->previous = current->previous;
            }
            
            if(current->previous != NULL)
            {
                current->previous->next = current->next;
            }
            else
            {
                current->owner->event = current->next;
            }
            
            /* removing event */
            kvo->event_count--;
            pthread_mutex_destroy(&(current->in_use));
            free(current);
        }
    }
    
    PTHREAD_RWLOCK_DEBUG_IMP_UNLOCK(&(kvo->event_rwlock));
}
