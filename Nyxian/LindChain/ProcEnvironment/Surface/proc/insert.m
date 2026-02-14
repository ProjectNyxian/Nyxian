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

#import <LindChain/ProcEnvironment/Surface/proc/insert.h>
#import <LindChain/ProcEnvironment/Surface/proc/def.h>

ksurface_return_t proc_insert(ksurface_proc_t *proc)
{
    if(proc == NULL)
    {
        return SURFACE_NULLPTR;
    }
    
    if(!kvo_retain(proc))
    {
        return SURFACE_RETAIN_FAILED;
    }
    
    proc_table_wrlock();
    
    ksurface_return_t err = SURFACE_SUCCESS;
    
    if(ksurface->proc_info.proc_count >= PROC_MAX)
    {
        err = SURFACE_LIMIT;
        goto out_unlock;
    }
    
    if(radix_lookup(&(ksurface->proc_info.tree), proc_getpid(proc)) != NULL)
    {
        err = SURFACE_DUPLICATE;
        goto out_unlock;
    }
    
    if(radix_insert(&(ksurface->proc_info.tree), proc_getpid(proc), proc) != 0)
    {
        err = SURFACE_FAILED;
        goto out_unlock;
    }
    
    ksurface->proc_info.proc_count++;
    
out_unlock:
    proc_table_unlock();
    
    if(err != SURFACE_SUCCESS)
    {
        kvo_release(proc);
    }
    
    return err;
}
