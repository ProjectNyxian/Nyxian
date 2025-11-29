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

ksurface_error_t proc_remove_by_pid(pid_t pid)
{
    /* Null pointer check */
    if(ksurface == NULL) return kSurfaceErrorNullPtr;
    
    /* Aquire rw lock */
    pthread_mutex_lock(&(ksurface->proc_info.wl));
    
    /* Finding target process */
    ksurface_proc_t *found_proc = NULL;
    unsigned long found_idx = 0;
    for(unsigned long i = 0; i < ksurface->proc_info.proc_count; i++)
    {
        ksurface_proc_t *p = ksurface->proc_info.proc[i];
        if(p && p->bsd.kp_proc.p_pid == pid)
        {
            found_idx = i;
            found_proc = p;
            break;
        }
    }
    
    /* Diding found process */
    if(found_proc == NULL)
    {
        pthread_mutex_unlock(&(ksurface->proc_info.wl));
        return kSurfaceErrorNotFound;
    }
    
    /* Marking process as dead */
    atomic_store(&found_proc->dead, true);
    
    /* Removing from table by swapping the last entry into the process entry */
    uint32_t last_idx = ksurface->proc_info.proc_count - 1;
    if(found_idx != last_idx)
    {
        rcu_assign_pointer(ksurface->proc_info.proc[found_idx], ksurface->proc_info.proc[last_idx]);
    }
    rcu_assign_pointer(ksurface->proc_info.proc[last_idx], NULL);
    atomic_store(&ksurface->proc_info.proc_count, last_idx);
    
    /* Releasing rw lock and process */
    pthread_mutex_unlock(&(ksurface->proc_info.wl));
    synchronize_rcu(&(ksurface->proc_info.rcu));
    proc_release(found_proc);
    
    /* Succeeded */
    return kSurfaceErrorSuccess;
}
