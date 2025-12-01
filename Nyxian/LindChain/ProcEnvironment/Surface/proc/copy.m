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
#import <LindChain/ProcEnvironment/Surface/proc/reference.h>
#import <LindChain/ProcEnvironment/Surface/proc/rw.h>

ksurface_proc_copy_t *proc_copy_for_proc(ksurface_proc_t *proc,
                                         enum kProcCopyOption option)
{
    /* null pointer check */
    if(proc == NULL)
    {
        return NULL;
    }
    
    /* retaining process before doing anything */
    if(!proc_retain(proc))
    {
        /* in-case it consume the processes reference then there is no tolerance consume is consume */
        if(option == kProcCopyOptionConsumeReference)
        {
            /* release to "consume" */
            proc_release(proc);
        }
        return NULL;
    }
    
    /* checking if the option is to consume reference */
    if(option == kProcCopyOptionConsumeReference)
    {
        /* release to "consume" */
        proc_release(proc);
    }
    
    /* allocating copy */
    ksurface_proc_copy_t *proc_copy = malloc(sizeof(ksurface_proc_copy_t));
    
    /* null pointer check */
    if(proc_copy == NULL)
    {
        proc_release(proc);
        return NULL;
    }
    
    /* setting original pointer to reference to the process */
    proc_copy->original = proc;
    
    /* copying the process to the copy */
    proc_read_lock(proc);
    memcpy(&(proc_copy->bsd), &(proc->bsd), sizeof(kinfo_proc_t));
    memcpy(&(proc_copy->nyx), &(proc->nyx), sizeof(knyx_proc_t));
    proc_unlock(proc);
    
    /* boom here you go */
    return proc_copy;
}

ksurface_error_t proc_copy_update(ksurface_proc_copy_t *proc_copy)
{
    /* null pointer check */
    if(proc_copy == NULL || proc_copy->original == NULL)
    {
        return kSurfaceErrorNullPtr;
    }
    
    /* update the original reference */
    proc_write_lock(proc_copy->original);
    memcpy(&(proc_copy->original->bsd), &(proc_copy->bsd), sizeof(kinfo_proc_t));
    memcpy(&(proc_copy->original->nyx), &(proc_copy->nyx), sizeof(knyx_proc_t));
    proc_unlock(proc_copy->original);
    
    return kSurfaceErrorSuccess;
}

ksurface_error_t proc_copy_recopy(ksurface_proc_copy_t *proc_copy)
{
    /* null pointer check */
    if(proc_copy == NULL || proc_copy->original == NULL)
    {
        return kSurfaceErrorNullPtr;
    }
    
    /* update the copy */
    proc_read_lock(proc_copy->original);
    memcpy(&(proc_copy->bsd), &(proc_copy->original->bsd), sizeof(kinfo_proc_t));
    memcpy(&(proc_copy->nyx), &(proc_copy->original->nyx), sizeof(knyx_proc_t));
    proc_unlock(proc_copy->original);
    
    return kSurfaceErrorSuccess;
}

ksurface_error_t proc_copy_destroy(ksurface_proc_copy_t *proc_copy)
{
    /* null pointer check */
    if(proc_copy == NULL)
    {
        return kSurfaceErrorNullPtr;
    }
    
    /* release reference to process */
    proc_release(proc_copy->original);
    
    /* freeing copy */
    free(proc_copy);
    
    return kSurfaceErrorSuccess;
}
