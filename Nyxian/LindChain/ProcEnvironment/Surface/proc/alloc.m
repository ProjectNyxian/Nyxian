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

#import <LindChain/ProcEnvironment/Surface/proc/alloc.h>
#import <LindChain/ProcEnvironment/Surface/proc/helper.h>

ksurface_error_t proc_alloc_proc(ksurface_proc_t **proc)
{
    if(proc == NULL) return kSurfaceErrorNullPtr;
    
    *proc = NULL;
    
    for(uint32_t i = 0; i < PROC_MAX; i++)
    {
        if((__atomic_exchange_n(&(surface->proc_info.proc[i].inUse), true, __ATOMIC_ACQUIRE) == 0))
        {
            seqlock_lock(&(surface->proc_info.proc[i].seqlock));
            *proc = &surface->proc_info.proc[i];
            memset(((char *)*proc) + sizeof(seqlock_t), 0, sizeof(ksurface_proc_t) - sizeof(seqlock_t));
            seqlock_unlock(&(surface->proc_info.proc[i].seqlock));
            break;
        }
    }
    
    return (*proc == NULL) ? kSurfaceErrorOutOfBounds : kSurfaceErrorSuccess;
}

ksurface_error_t proc_release_proc(ksurface_proc_t *proc)
{
    if(proc == NULL) return kSurfaceErrorNullPtr;
    return (__atomic_exchange_n(&(proc->inUse), false, __ATOMIC_RELEASE) == 0) ? kSurfaceErrorUndefined : kSurfaceErrorSuccess;
}
