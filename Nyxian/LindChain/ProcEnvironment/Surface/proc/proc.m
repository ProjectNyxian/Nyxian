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

#import <LindChain/ProcEnvironment/Surface/proc/proc.h>

ksurface_error_t proc_can_spawn(void)
{
    // Dont use if uninitilized
    if(surface == NULL) return kSurfaceErrorNullPtr;
    
    // Aquiring rw lock (Its from biggest necessarity to make sure that no process gets added while we check if a process is allowed to spawn)
    seqlock_lock(&(surface->seqlock));
    
    // Return value
    ksurface_error_t retval = kSurfaceErrorUndefined;
    
    // Checking if process count is underneath PROC_MAX
    if(surface->proc_info.proc_count < PROC_MAX)
    {
        // Setting return value to succession
        retval = kSurfaceErrorSuccess;
    }
    
    // Releasing rw lock
    seqlock_unlock(&(surface->seqlock));
    
    // Returning return value
    return retval;
}
