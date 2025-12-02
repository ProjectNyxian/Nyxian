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
#import <LindChain/ProcEnvironment/Surface/proc/rw.h>
#import <LindChain/ProcEnvironment/Surface/proc/def.h>

ksurface_error_t proc_insert(ksurface_proc_t *proc)
{
    /* Null pointer check */
    if(ksurface == NULL || proc == NULL)
    {
        return kSurfaceErrorNullPtr;
    }
    
    /* Get pid of process */
    pid_t pid = proc_getpid(proc);
    
    /* Aquire rw lock */
    proc_table_write_lock();
    
    /* Looking up the radix tree */
    if(radix_lookup(&(ksurface->proc_info.tree), pid) != NULL)
    {
        proc_table_unlock();
        return kSurfaceErrorPidInUse;
    }
    
    /* Insert into tree*/
    if(radix_insert(&(ksurface->proc_info.tree), pid, proc) != 0)
    {
        proc_table_unlock();
        return kSurfaceErrorNoMemory;
    }
    
    /* Retaining process */
    proc_retain(proc);
    
    /* Releasing table lock */
    proc_table_unlock();
    
    return kSurfaceErrorSuccess;
}
