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
#import <LindChain/ProcEnvironment/Surface/proc/reference.h>
#import <LindChain/ProcEnvironment/Surface/proc/rw.h>
#include <stdatomic.h>

ksurface_error_t proc_remove_by_pid(pid_t pid)
{
    /* Null pointer check */
    if(ksurface == NULL)
    {
        return kSurfaceErrorNullPtr;
    }
    
    /* Aquire rw lock */
    proc_table_write_lock();
    
    /* Getting target process */
    ksurface_proc_t *proc = radix_remove(&(ksurface->proc_info.tree), pid);
    if(proc == NULL)
    {
        proc_table_unlock();
        return kSurfaceErrorNotFound;
    }
    
    /* Marking process as dead */
    atomic_store(&(proc->dead), true);
    
    /* Release process */
    proc_release(proc);
    
    /* Unlocking table */
    proc_table_unlock();
    
    /* Succeeded */
    return kSurfaceErrorSuccess;
}
