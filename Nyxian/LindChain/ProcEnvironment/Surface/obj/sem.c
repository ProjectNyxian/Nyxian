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

#import <LindChain/ProcEnvironment/Surface/obj/sem.h>
#import <LindChain/ProcEnvironment/Surface/obj/event.h>
#include <assert.h>
#include <stdlib.h>

void kvobject_sem_handler(kvobject_strong_t *kvo,
                          kvevent_type_t type,
                          uint8_t value,
                          void *pld)
{
    assert(pld != NULL);
    
    semaphore_t *sema = (semaphore_t*)pld;
    
    if(type == kvObjEventDeinit || type == kvObjEventUnregister)
    {
        semaphore_destroy(mach_task_self(), *sema);
        free(pld);
    }
    
    semaphore_signal(*sema);
}

ksurface_return_t kvobject_register_sem(kvobject_strong_t *kvo,
                                        kvevent_type_t type,
                                        uint64_t *token,
                                        semaphore_t *sem_port)
{
    assert(kvo != NULL || sem_port != NULL);
    
    semaphore_t *pld = malloc(sizeof(semaphore_t));
    
    if(pld == NULL)
    {
        return SURFACE_NOMEM;
    }
    
    kern_return_t kr = semaphore_create(mach_task_self(), pld, POLICY_FIFO, 0);
    if(kr != KERN_SUCCESS)
    {
        free(pld);
        return SURFACE_FAILED;
    }
    
    ksurface_return_t ksr = kvobject_event_register(kvo, kvobject_sem_handler, type, token, pld);
    
    if(ksr == SURFACE_SUCCESS)
    {
        *sem_port = *pld;
    }
    
    return ksr;
}
