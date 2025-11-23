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

#import <LindChain/ProcEnvironment/Surface/proc/fetch.h>
#import <LindChain/ProcEnvironment/Surface/proc/def.h>

ksurface_error_t proc_for_pid(pid_t pid,
                              ksurface_proc_t *proc)
{
    // Check to ensure its not a nullified surface or better said
    if(surface == NULL || proc == NULL) return kSurfaceErrorNullPtr;
    
    // Preparing error
    ksurface_error_t retval = kSurfaceErrorNotFound;
    
    // Sequence
    unsigned long seq;
    
    // Beginning to spin, to hopefully find the processes requested
    do
    {
        seq = reflock_read_begin(&(surface->reflock));
        
        // Iterating through all process structures
        for(uint32_t i = 0; i < surface->proc_info.proc_count; i++)
        {
            // Checking if its the process structure were looking for
            if(proc_getpid(surface->proc_info.proc[i]) == pid)
            {
                // Copying it to the process ptr passed
                *proc = surface->proc_info.proc[i];
                
                // Setting return value to success
                retval = kSurfaceErrorSuccess;
                break;
            }
        }
    }
    while (reflock_read_retry(&(surface->reflock), seq));
    
    // Returning return value
    return retval;
}
ksurface_error_t proc_for_index(unsigned int idx,
                              ksurface_proc_t *proc)
{
    // Check to ensure its not a nullified surface or better said
    if(surface == NULL || proc == NULL) return kSurfaceErrorNullPtr;
    
    // Preparing error
    ksurface_error_t retval = kSurfaceErrorNotFound;
    
    // Sequence
    unsigned long seq;
    
    // Beginning to spin, to hopefully find the processes requested
    do
    {
        seq = reflock_read_begin(&(surface->reflock));
        
        // Checking if the index is within bounds
        if(idx < surface->proc_info.proc_count)
        {
            // Copying process at index to the pointer provided
            *proc = surface->proc_info.proc[idx];
            
            // Setting return value to succeed
            retval = kSurfaceErrorSuccess;
        }
    }
    while (reflock_read_retry(&(surface->reflock), seq));
    
    // Returning return value
    return retval;
}
