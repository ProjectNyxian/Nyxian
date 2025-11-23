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

#import <LindChain/ProcEnvironment/Surface/proc/replace.h>
#import <LindChain/ProcEnvironment/Surface/proc/def.h>

ksurface_error_t proc_replace(ksurface_proc_t proc)
{
    // Dont use if uninitilized
    if(surface == NULL) return kSurfaceErrorNullPtr;
    
    // Aquiring rw lock
    reflock_lock(&(surface->reflock));
    
    // Iterating through all processes
    for(uint32_t i = 0; i < surface->proc_info.proc_count; i++)
    {
        // Checking if the process at a certain position in memory matches the provided process that we wanna insert
        if(proc_getpid(surface->proc_info.proc[i]) == proc_getpid(proc))
        {
            // Copying provided process onto the surface at already existing memory entry
            proc_cpy(surface->proc_info.proc[i], proc);
            
            reflock_unlock(&(surface->reflock));
            
            return kSurfaceErrorSuccess;
        }
    }
    
    // Releasing rw lock
    reflock_unlock(&(surface->reflock));
    
    // It succeeded
    return kSurfaceErrorSuccess;
}
