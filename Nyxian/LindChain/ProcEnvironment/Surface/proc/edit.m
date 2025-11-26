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

#import <LindChain/ProcEnvironment/Surface/proc/edit.h>
#import <LindChain/ProcEnvironment/Surface/proc/fetch.h>

ksurface_error_t proc_edit_task_role_for_pid(pid_t pid,
                                             task_role_t role)
{
    // Check if surface is a null pointer
    if(surface == NULL) return kSurfaceErrorNullPtr;
    
    // Override task role
    bool taskRoleOverride = (role != TASK_NONE);
    ksurface_error_t error = kSurfaceErrorSuccess;
    
    // Aquire reflock
    reflock_lock(&surface->reflock);
    
    // Get proc structure pointer
    ksurface_proc_t *proc = NULL;
    error = proc_ptr_for_pid(pid, &proc);
    if(error != kSurfaceErrorSuccess)
    {
        reflock_unlock(&surface->reflock);
        return error;
    }
    
    // Set override properties
    proc->nyx.force_task_role_override = taskRoleOverride;
    proc->nyx.task_role_override = role;
    
    // Release reflock
    reflock_unlock(&surface->reflock);
    
    // Return if something bad happened here
    return error;
}
