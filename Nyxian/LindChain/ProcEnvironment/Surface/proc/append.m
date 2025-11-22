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

#import <LindChain/ProcEnvironment/Surface/proc/append.h>
#import <LindChain/ProcEnvironment/Surface/proc/helper.h>

static inline ksurface_error_t proc_append_internal(ksurface_proc_t proc,
                                                    bool use_lock)
{
    // Dont use if uninitilized
    if(surface == NULL) return kSurfaceErrorNullPtr;
    
    // Aquiring rw lock if applicable
    proc_helper_lock(use_lock);
    
    // Iterating through all processes
    for(uint32_t i = 0; i < surface->proc_count; i++)
    {
        // Checking if the process at a certain position in memory matches the provided process that we wanna insert
        if(surface->proc[i].bsd.kp_proc.p_pid == proc.bsd.kp_proc.p_pid)
        {
            proc_helper_unlock(use_lock);
            return kSurfaceErrorAlreadyExists;
        }
    }
    // It doesnt exist already so we copy it into the next new entry
    ksurface_error_t error = kSurfaceErrorSuccess;
    if(surface->proc_count < PROC_MAX)
    {
        memcpy(&surface->proc[surface->proc_count], &proc, sizeof(ksurface_proc_t));
        surface->proc_count++;
    }
    else
    {
        error = kSurfaceErrorOutOfBounds;
    }
    
    // Releasing rw lock if applicable
    proc_helper_unlock(use_lock);
    
    // It succeeded
    return error;
}

ksurface_error_t proc_append(ksurface_proc_t proc)
{
    return proc_append_internal(proc, true);
}

ksurface_error_t proc_append_nolock(ksurface_proc_t proc)
{
    return proc_append_internal(proc, false);
}
