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
    ksurface_error_t err = kSurfaceErrorSuccess;
    
    /* null pointer check */
    if(ksurface == NULL || proc == NULL)
    {
        return kSurfaceErrorNullPtr;
    }
    
    /* get pid of process */
    pid_t pid = proc_getpid(proc);
    
    /* Aquire rw lock */
    proc_table_write_lock();
    
    /* checking process count */
    if(ksurface->proc_info.proc_count >= PROC_MAX)
    {
        err = kSurfaceErrorFailed;
        goto out_unlock;
    }
    
    /* looking up the radix tree */
    if(radix_lookup(&(ksurface->proc_info.tree), pid) != NULL)
    {
        err = kSurfaceErrorPidInUse;
        goto out_unlock;
    }
    
    /* retaining process */
    if(!proc_retain(proc))
    {
        err = kSurfaceErrorFailed;
        goto out_unlock;
    }
    
    /* insert into tree*/
    if(radix_insert(&(ksurface->proc_info.tree), pid, proc) != 0)
    {
        proc_release(proc);
        err = kSurfaceErrorNoMemory;
        goto out_unlock;
    }
    
    /* counting up */
    ksurface->proc_info.proc_count++;
    
out_unlock:
    proc_table_unlock();
    return err;
}
