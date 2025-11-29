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

#import <LindChain/ProcEnvironment/Surface/proc/reference.h>
#import <LindChain/ProcEnvironment/Surface/proc/insert.h>
#import <LindChain/ProcEnvironment/Surface/proc/def.h>

ksurface_error_t proc_insert(ksurface_proc_t *proc)
{
    /* Null pointer check */
    if(ksurface == NULL || proc == NULL) return kSurfaceErrorNullPtr;
    
    /* Aquire rw lock */
    pthread_mutex_lock(&(ksurface->proc_info.wl));
    
    /* Bounds check */
    if(ksurface->proc_info.proc_count >= PROC_MAX)
    {
        /* Its out of bounds */
        pthread_mutex_unlock(&(ksurface->proc_info.wl));
        return kSurfaceErrorOutOfBounds;
    }
    
    /* Retaining process */
    proc_retain(proc);
    
    /* Adding process */
    rcu_assign_pointer(ksurface->proc_info.proc[ksurface->proc_info.proc_count++], proc);
    pthread_mutex_unlock(&(ksurface->proc_info.wl));
    return kSurfaceErrorSuccess;
}
