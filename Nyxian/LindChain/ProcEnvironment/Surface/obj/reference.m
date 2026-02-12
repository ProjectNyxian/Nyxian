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

#import <LindChain/ProcEnvironment/Surface/obj/reference.h>
#import <LindChain/ProcEnvironment/Utils/klog.h>
#import <LindChain/ProcEnvironment/panic.h>
#include <stdlib.h>

bool kvobject_retain(kvobject_t *kvo)
{    
    /* performing retain if valid */
    while(1)
    {
        /* getting current reference count */
        int current = atomic_load(&kvo->refcount);
        
        /* checking if object can be retained */
        if(current <= 0 || atomic_load(&kvo->invalid))
        {
            return false;
        }
        
        /* retaining process */
        if(atomic_compare_exchange_weak(&kvo->refcount, &current, current + 1))
        {
            /* performing another check */
            if(atomic_load(&kvo->invalid))
            {
                /* its not so boom im sorry */
                atomic_fetch_sub(&kvo->refcount, 1);
                return false;
            }
            return true;
        }
    }
}

void kvobject_invalidate(kvobject_t *kvo)
{
    /* invalidating object */
    atomic_store(&(kvo->invalid), true);
    
    /* returning */
    return;
}


void kvobject_release(kvobject_t *kvo)
{
    /* releasing and trying to get the old reference count */
    int old = atomic_fetch_sub(&kvo->refcount, 1);
    if(old == 1)
    {
        klog_log(@"kvobject:release", @"freeing process @ %p", kvo);
        
        /* checking for deinit handler and executing if nonnull */
        if(kvo->deinit != NULL)
        {
            kvo->deinit(kvo);
        }
        
        pthread_rwlock_destroy(&(kvo->rwlock));
        free(kvo);
    }
    else if(old <= 0)
    {
        /*
         * happens on reference underflow, by design a
         * panic cuz this never happens legitimately
         */
        environment_panic();
    }
    
    return;
}
