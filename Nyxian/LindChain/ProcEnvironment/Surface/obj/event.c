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
#import <stdlib.h>
#import <assert.h>

ksurface_return_t kvobject_event_register(kvobject_strong_t *kvo,
                                          kvobject_event_handler_t handler,
                                          void *context,
                                          kvobject_event_t **event)
{
    assert(kvo != NULL && handler != NULL && kvo->base_type != kvObjBaseTypeObjectSnapshot);
    
    pthread_rwlock_wrlock(&(kvo->event_rwlock));
    
    /* find last event */
    uint16_t event_cnt = 0;
    kvobject_event_t *last_event = kvo->event;
    if(last_event != NULL)
    {
        while(last_event->next != NULL)
        {
            event_cnt++;
            last_event = last_event->next;
        }
    }
    
    if(event_cnt > KVOBJECT_EVENT_MAX)
    {
        return SURFACE_LIMIT;
    }
    
    /* allocating new event */
    kvobject_event_t *e_event = malloc(sizeof(kvobject_event_t));
    
    if(e_event == NULL)
    {
        pthread_rwlock_unlock(&(kvo->event_rwlock));
        return SURFACE_NOMEM;
    }
    
    /* setting properties */
    e_event->previous = last_event;
    e_event->next = NULL;
    e_event->owner = kvo;
    e_event->handler = handler;
    e_event->ctx = context;
    
    /* now insert new event */
    if(last_event == NULL)
    {
        kvo->event = e_event;
    }
    else
    {
        last_event->next = e_event;
    }
    
    /* if event back pointer is givven, set it */
    if(event != NULL)
    {
        *event = e_event;
    }
    
    pthread_rwlock_unlock(&(kvo->event_rwlock));
    
    return SURFACE_SUCCESS;
}

ksurface_return_t kvobject_event_unregister(kvobject_event_t *event)
{
    assert(event != NULL && event->owner != NULL);
    
    /*
     * we need a reference to the owner
     * so it cannot and then cause a data
     * corruption.
     */
    if(!kvo_retain(event->owner))
    {
        return SURFACE_RETAIN_FAILED;
    }
    
    /* locking the structure obviously */
    pthread_rwlock_wrlock(&(event->owner->event_rwlock));
    
    /* triggering event */
    event->handler(kvObjEventUnregister, 0, event);
    
    /* relinking previous and next */
    if(event->previous != NULL)
    {
        event->previous->next = event->next;
    }
    
    if(event->next != NULL)
    {
        event->next->previous = event->previous;
    }
    
    if(event->previous == NULL)
    {
        event->owner->event = event->next;
    }
    
    /* releasing locks and resources */
    pthread_rwlock_unlock(&(event->owner->event_rwlock));
    kvo_release(event->owner);
    free(event);
    
    return SURFACE_SUCCESS;
}

void kvobject_event_trigger(kvobject_strong_t *kvo,
                            kvobject_event_type_t type,
                            uint8_t value)
{
    assert(kvo != NULL && type != kvObjEventCopy);
    
    /* sanity checking object type */
    if(kvo->base_type != kvObjBaseTypeObject)
    {
        return;
    }
    
    pthread_rwlock_wrlock(&(kvo->event_rwlock));
    
    /*
     * execute all events in the chain and remove
     * events that wanna be removed(return true).
     */
    kvobject_event_t *last_event = kvo->event;
    while(last_event != NULL)
    {
        /* pointer to current event */
        kvobject_event_t *current = last_event;
        
        /* calling event handler */
        bool will_remove = current->handler(type, value, current);
        
        /* deinit is always removal */
        if(type == kvObjEventDeinit)
        {
            will_remove = true;
        }
        
        /* updating last event */
        last_event = current->next;
        
        /* remove if applicable */
        if(will_remove)
        {
            /* triggering unregistration event */
            current->handler(kvObjEventUnregister, 0, current);
            
            /* relinking previous and next */
            if(current->previous != NULL)
            {
                current->previous->next = current->next;
            }
            
            if(current->next != NULL)
            {
                current->next->previous = current->previous;
            }
            
            if(current->previous == NULL) {
                current->owner->event = current->next;
            }
            
            /* freeing  event */
            free(current);
        }
    }
    
    /* the main event handler shall always be called */
    kvo->main_handler(&kvo, type);
    
    pthread_rwlock_unlock(&(kvo->event_rwlock));
}
