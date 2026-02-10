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

#import <LindChain/ProcEnvironment/Surface/obj/copy.h>
#import <LindChain/ProcEnvironment/Surface/obj/reference.h>
#import <LindChain/ProcEnvironment/Surface/obj/lock.h>
#include <stdlib.h>
#include <string.h>

kvobject_t *kvobject_copy(kvobject_t *kvo,
                          kvobj_copy_option_t option)
{
    /* null pointer check */
    if(kvo == NULL)
    {
        return NULL;
    }
    
    /* retaining process before doing anything */
    if(kvobject_retain(kvo) != kSurfaceReturnSuccess)
    {
        /* in-case it consume the objects reference then there is no tolerance consume is consume */
        return NULL;
    }
    
    /* allocating copy */
    kvobject_t *kvo_copy = malloc(kvo->size);
    
    /* null pointer check */
    if(kvo_copy == NULL)
    {
        kvobject_release(kvo);
        return NULL;
    }
    
    /* setting original pointer to reference to the object, but not if its a static copy */
    if(option != kObjCopyOptionStaticCopy)
    {
        kvo_copy->copy_link = kvo;
    }
    else
    {
        kvo_copy->copy_link = NULL;
    }
    
    /* copying the original object to the copy (always past the kvobject header) */
    kvobject_rdlock(kvo);
    memcpy(kvo_copy + sizeof(kvobject_t), kvo + sizeof(kvobject_t), kvo->size - sizeof(kvobject_t));
    kvobject_unlock(kvo);
    
    /* running init again if applicable (note that you can check in init handler if its a copy) */
    if(kvo->init != NULL)
    {
        kvo->init(kvo_copy);
    }
    
    /* checking if its consumed reference */
    if(option == kObjCopyOptionConsumedReferenceCopy ||
       option == kObjCopyOptionStaticCopy)
    {
        kvobject_release(kvo);
    }
    
    /* boom here you go */
    return kvo_copy;
}

ksurface_return_t kvobject_copy_update(kvobject_t *kvo_copy)
{
    /* null pointer check */
    if(kvo_copy == NULL ||
       kvo_copy->copy_link == NULL)
    {
        return kSurfaceReturnNullPtr;
    }
    
    /* checking if its a copy */
    if(!kvo_copy->copy_is)
    {
        return kSurfaceReturnFailed;
    }
    
    /* update the original reference */
    kvobject_wrlock(kvo_copy->copy_link);
    memcpy(kvo_copy->copy_link + sizeof(kvobject_t), kvo_copy + sizeof(kvobject_t), kvo_copy->copy_link->size - sizeof(kvobject_t));
    kvobject_rdlock(kvo_copy->copy_link);
    
    return kSurfaceReturnSuccess;
}

ksurface_return_t kvobject_copy_recopy(kvobject_t *kvo_copy)
{
    /* null pointer check */
    if(kvo_copy == NULL ||
       kvo_copy->copy_link == NULL)
    {
        return kSurfaceReturnNullPtr;
    }
    
    /* checking if its a copy */
    if(!kvo_copy->copy_is)
    {
        return kSurfaceReturnFailed;
    }
    
    /* update the copy */
    kvobject_wrlock(kvo_copy->copy_link);
    memcpy(kvo_copy + sizeof(kvobject_t), kvo_copy->copy_link + sizeof(kvobject_t), kvo_copy->copy_link->size - sizeof(kvobject_t));
    kvobject_rdlock(kvo_copy->copy_link);
    
    return kSurfaceReturnSuccess;
}

ksurface_return_t kvobject_copy_destroy(kvobject_t *kvo_copy)
{
    /* null pointer check */
    if(kvo_copy == NULL)
    {
        return kSurfaceReturnNullPtr;
    }
    
    /* checking if its a copy */
    if(!kvo_copy->copy_is)
    {
        return kSurfaceReturnFailed;
    }
    
    /* release reference to process, in case its there */
    if(kvo_copy->copy_link != NULL)
    {
        kvobject_release(kvo_copy->copy_link);
    }
    
    /* freeing copy */
    free(kvo_copy);
    
    return kSurfaceReturnSuccess;
}
