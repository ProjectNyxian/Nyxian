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

#import <LindChain/ProcEnvironment/Surface/obj/event.h>
#import <assert.h>

ksurface_return_t kvobject_event_register(kvobject_strong_t *kvo,
                                          kvobject_event_handler_t handler,
                                          kvevent_type_t type,
                                          uint64_t *token,
                                          void *pld)
{
    assert(kvo != NULL || handler != NULL);
    
    pthread_rwlock_wrlock(&(kvo->event_rwlock));
    
    /* limit checking if event count is exceeded */
    if(kvo->event_cnt >= KVEVENT_MAX)
    {
        pthread_rwlock_unlock(&(kvo->event_rwlock));
        return SURFACE_LIMIT;
    }
    
    /* aquiring next event */
    kvevent_t *event = &(kvo->event[kvo->event_cnt++]);
    
    /* setting up event */
    event->handler = handler;
    event->type = type;
    event->event_token = kvo->event_token_counter++;
    event->pld = pld;
    
    /* setting event token if applicable */
    if(token != NULL)
    {
        *token = event->event_token;
    }
    
    pthread_rwlock_unlock(&(kvo->event_rwlock));
    
    return SURFACE_SUCCESS;
}

ksurface_return_t kvobject_event_unregister(kvobject_strong_t *kvo,
                                            uint64_t token)
{
    assert(kvo != NULL);
    
    pthread_rwlock_wrlock(&(kvo->event_rwlock));
    
    uint8_t event_idx = 0;
    kvevent_t *event = NULL;
    
    /* find exact event */
    for(uint8_t i = 0; i < kvo->event_cnt; i++)
    {
        if(kvo->event[i].event_token == token)
        {
            event_idx = 0;
            event = &(kvo->event[i]);
            break;
        }
    }
    
    /* sanity check */
    if(event == NULL)
    {
        pthread_rwlock_unlock(&(kvo->event_rwlock));
        return SURFACE_LOOKUP_FAILED;
    }
    
    if(kvo->event_cnt > 1)
    {
        /*
         * overriding event at index with the last
         * event.
         */
        kvo->event[event_idx] = kvo->event[kvo->event_cnt - 1];
    }
    
    /* one event less */
    kvo->event_cnt--;
    
    pthread_rwlock_unlock(&(kvo->event_rwlock));
    
    return SURFACE_SUCCESS;
}

void kvobject_event_trigger(kvobject_strong_t *kvo,
                            kvevent_type_t type,
                            uint8_t value)
{
    assert(kvo != NULL);
    
    pthread_rwlock_wrlock(&(kvo->event_rwlock));
    
    /* find all events and execute */
    for(uint8_t i = 0; i < kvo->event_cnt; i++)
    {
        if(kvo->event[i].type == type)
        {
            kvo->event[i].handler(kvo,type,value,kvo->event[i].pld);
        }
    }
    
    pthread_rwlock_unlock(&(kvo->event_rwlock));
}
