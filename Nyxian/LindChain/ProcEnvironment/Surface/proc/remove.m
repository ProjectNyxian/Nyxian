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

#import <LindChain/ProcEnvironment/Surface/proc/remove.h>
#import <LindChain/ProcEnvironment/Surface/proc/helper.h>

static inline ksurface_error_t proc_remove_by_pid_internal(pid_t pid,
                                                           bool use_lock)
{
    // Dont use if uninitilized
    if(surface == NULL) return kSurfaceErrorNullPtr;
    
    // Aquiring rw lock
    proc_helper_lock(use_lock);

    // Return value
    ksurface_error_t retval = kSurfaceErrorNotFound;
    
    // Iterating through all processes
    for(uint32_t i = 0; i < surface->proc_count; i++)
    {
        // Checking if its the process were looking for
        if(surface->proc[i].bsd.kp_proc.p_pid == pid)
        {
            // Some check i dont remember why I wrote, I need to remember writing comments ong
            // MARK: Find out if its safe plaxinf proc_count-- here instead of in the if condition
            if(i < surface->proc_count - 1)
            {
                // Removing process from process structure by moving the process struture in front of it to it
                memmove(&surface->proc[i],
                        &surface->proc[i + 1],
                        (surface->proc_count - i - 1) * sizeof(ksurface_proc_t));
            }
            
            // Decrementing the count of processes
            surface->proc_count--;
            
            // Setting return value to succession
            retval = kSurfaceErrorSuccess;
            break;
        }
    }

    // Releasing rw lock
    proc_helper_unlock(use_lock);
    
    // Returning return value
    return retval;
}

ksurface_error_t proc_remove_by_pid(pid_t pid)
{
    return proc_remove_by_pid_internal(pid, true);
}

ksurface_error_t proc_remove_by_pid_nolock(pid_t pid)
{
    return proc_remove_by_pid_internal(pid, false);
}
