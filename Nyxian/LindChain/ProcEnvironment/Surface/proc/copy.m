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

#import <LindChain/ProcEnvironment/Surface/proc/copy.h>
#import <LindChain/ProcEnvironment/Surface/proc/rw.h>

ksurface_proc_copy_t *proc_copy_for_proc(ksurface_proc_t *proc,
                                         kproc_copy_option_t option)
{
    /* null pointer check */
    if(proc == NULL)
    {
        return NULL;
    }
    
    /* retaining process before doing anything */
    if(!kvo_retain(proc))
    {
        /* in-case it consume the processes reference then there is no tolerance consume is consume */
        return NULL;
    }
    
    /* allocating copy */
    ksurface_proc_copy_t *proc_copy = malloc(sizeof(ksurface_proc_copy_t));
    
    /* null pointer check */
    if(proc_copy == NULL)
    {
        kvo_release(proc);
        return NULL;
    }
    
    /* setting original pointer to reference to the process, but not if its a static copy */
    if(option != kProcCopyOptionStaticCopy)
    {
        proc_copy->proc = proc;
    }
    else
    {
        proc_copy->proc = NULL;
    }
    
    /* copying the process to the copy */
    kvo_rdlock(proc);
    memcpy(&(proc_copy->kproc.kcproc), &(proc->kproc.kcproc), sizeof(ksurface_kcproc_t));
    kvo_unlock(proc);
    
    /* checking if its consumed reference */
    if(option == kProcCopyOptionConsumedReferenceCopy ||
       option == kProcCopyOptionStaticCopy)
    {
        kvo_release(proc);
    }
    
    /* boom here you go */
    return proc_copy;
}

ksurface_return_t proc_copy_update(ksurface_proc_copy_t *proc_copy)
{
    /* null pointer check */
    if(proc_copy == NULL ||
       proc_copy->proc == NULL)
    {
        return kSurfaceReturnNullPtr;
    }
    
    /* update the original reference */
    kvo_wrlock(proc_copy->proc);
    memcpy(&(proc_copy->proc->kproc.kcproc), &(proc_copy->kproc.kcproc), sizeof(ksurface_kcproc_t));
    kvo_unlock(proc_copy->proc);
    
    return kSurfaceReturnSuccess;
}

ksurface_return_t proc_copy_recopy(ksurface_proc_copy_t *proc_copy)
{
    /* null pointer check */
    if(proc_copy == NULL ||
       proc_copy->proc == NULL)
    {
        return kSurfaceReturnNullPtr;
    }
    
    /* update the copy */
    kvo_rdlock(proc_copy->proc);
    memcpy(&(proc_copy->kproc.kcproc), &(proc_copy->proc->kproc.kcproc), sizeof(ksurface_kcproc_t));
    kvo_unlock(proc_copy->proc);
    
    return kSurfaceReturnSuccess;
}

ksurface_return_t proc_copy_destroy(ksurface_proc_copy_t *proc_copy)
{
    /* null pointer check */
    if(proc_copy == NULL)
    {
        return kSurfaceReturnNullPtr;
    }
    
    /* release reference to process, in case its there */
    if(proc_copy->proc != NULL)
    {
        kvo_release(proc_copy->proc);
    }
    
    /* freeing copy */
    free(proc_copy);
    
    return kSurfaceReturnSuccess;
}
