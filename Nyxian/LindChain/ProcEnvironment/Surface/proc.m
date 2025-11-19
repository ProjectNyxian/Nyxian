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

#import <LindChain/ProcEnvironment/environment.h>
#import <LindChain/ProcEnvironment/Surface/proc.h>
#include <LindChain/ProcEnvironment/Surface/lock/seqlock.h>
#import <pthread.h>
#include <stdio.h>
#include <sys/time.h>

ksurface_error_t proc_for_pid(pid_t pid,
                              ksurface_proc_t *proc)
{
    // Check to ensure its not a nullified surface or better said
    if(surface == NULL || proc == NULL) return kSurfaceErrorNullPtr;
    
    // Preparing error
    ksurface_error_t retval = kSurfaceErrorNotFound;
    
    // Beginning to spin, to hopefully find the processes requested
    do
    {
        seqlock_read_begin(&(surface->seqlock));
        
        // Iterating through all process structures
        for(uint32_t i = 0; i < surface->proc_count; i++)
        {
            // Checking if its the process structure were looking for
            if(surface->proc[i].bsd.kp_proc.p_pid == pid)
            {
                // Copying it to the process ptr passed
                *proc = surface->proc[i];
                
                // Setting return value to success
                retval = kSurfaceErrorSuccess;
                break;
            }
        }
    }
    while (seqlock_read_retry(&(surface->seqlock)));
    
    // Returning return value
    return retval;
}

ksurface_error_t proc_remove_for_pid(pid_t pid)
{
    // Dont use if uninitilized
    if(surface == NULL) return kSurfaceErrorNullPtr;
    
    // Aquiring rw lock
    seqlock_lock(&(surface->seqlock));

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
    seqlock_unlock(&(surface->seqlock));
    
    // Returning return value
    return retval;
}

ksurface_error_t proc_can_spawn(void)
{
    // Dont use if uninitilized
    if(surface == NULL) return kSurfaceErrorNullPtr;
    
    // Aquiring rw lock (Its from biggest necessarity to make sure that no process gets added while we check if a process is allowed to spawn)
    seqlock_lock(&(surface->seqlock));
    
    // Return value
    ksurface_error_t retval = kSurfaceErrorUndefined;
    
    // Checking if process count would exceed the maximum
    if(surface->proc_count < PROC_MAX)
    {
        // Setting return value to undefined, as a universal marker
        retval = kSurfaceErrorUndefined;
    }
    
    // Releasing rw lock
    seqlock_unlock(&(surface->seqlock));
    
    // Returning return value
    return retval;
}

ksurface_error_t proc_insert_proc(ksurface_proc_t proc)
{
    // Dont use if uninitilized
    if(surface == NULL) return kSurfaceErrorNullPtr;
    
    // Aquiring rw lock
    seqlock_lock(&(surface->seqlock));
    
    // Iterating through all processes
    for(uint32_t i = 0; i < surface->proc_count; i++)
    {
        // Checking if the process at a certain position in memory matches the provided process that we wanna insert
        if(surface->proc[i].bsd.kp_proc.p_pid == proc.bsd.kp_proc.p_pid)
        {
            // Copying provided process onto the surface at already existing memory entry
            memcpy(&surface->proc[i], &proc, sizeof(ksurface_proc_t));
            
            // Releasing rw lock
            seqlock_unlock(&(surface->seqlock));
            
            // It succeeded
            return kSurfaceErrorSuccess;
        }
    }
    
    // It doesnt exist already so we copy it into the next new entry
    memcpy(&surface->proc[surface->proc_count++], &proc, sizeof(ksurface_proc_t));
    
    // Releasing rw lock
    seqlock_unlock(&(surface->seqlock));
    
    // It succeeded
    return kSurfaceErrorSuccess;
}

ksurface_error_t proc_at_index(uint32_t index,
                               ksurface_proc_t *prot)
{
    // Dont use if uninitilized
    if(surface == NULL || prot == NULL) return kSurfaceErrorNullPtr;
    
    // Return value
    ksurface_error_t retval = kSurfaceErrorOutOfBounds;
    
    // Beginning to spin, to hopefully find the processes requested
    do
    {
        seqlock_read_begin(&(surface->seqlock));
        
        // Checking if the index is within bounds
        if(index < surface->proc_count)
        {
            // Copying process at index to the pointer provided
            *prot = surface->proc[index];
            
            // Setting return value to succeed
            retval = kSurfaceErrorSuccess;
        }
    }
    while (seqlock_read_retry(&(surface->seqlock)));
    
    // Returning return value
    return retval;
}

// MARK: New and safer approach, NO means execution not granted!
ksurface_error_t proc_add_proc(pid_t ppid,
                               pid_t pid,
                               uid_t uid,
                               gid_t gid,
                               NSString *executablePath,
                               PEEntitlement entitlement)
{
    ksurface_proc_t proc = {};
    
    // Set ksurface_proc properties
    proc.force_task_role_override = true;
    proc.task_role_override = TASK_UNSPECIFIED;
    proc.entitlements = entitlement;
    strncpy(proc.path, [[[NSURL fileURLWithPath:executablePath] path] UTF8String], PATH_MAX);
    
    // Set bsd process stuff
    struct timeval tv;
    if(gettimeofday(&tv, NULL) != 0) return NO;
    proc.bsd.kp_proc.p_un.__p_starttime.tv_sec = tv.tv_sec;
    proc.bsd.kp_proc.p_un.__p_starttime.tv_usec = tv.tv_usec;
    proc.bsd.kp_proc.p_flag = P_LP64 | P_EXEC;
    proc.bsd.kp_proc.p_stat = SRUN;
    proc.bsd.kp_proc.p_pid = pid;
    proc.bsd.kp_proc.p_oppid = ppid;
    proc.bsd.kp_proc.p_priority = PUSER;
    proc.bsd.kp_proc.p_usrpri = PUSER;
    strncpy(proc.bsd.kp_proc.p_comm, [[[NSURL fileURLWithPath:executablePath] lastPathComponent] UTF8String], MAXCOMLEN + 1);
    proc.bsd.kp_proc.p_acflag = 2;
    proc.bsd.kp_eproc.e_pcred.p_ruid = uid;
    proc.bsd.kp_eproc.e_pcred.p_svuid = uid;
    proc.bsd.kp_eproc.e_pcred.p_rgid = gid;
    proc.bsd.kp_eproc.e_pcred.p_svgid = gid;
    proc.bsd.kp_eproc.e_ucred.cr_ref = 5;
    proc.bsd.kp_eproc.e_ucred.cr_uid = uid;
    proc.bsd.kp_eproc.e_ucred.cr_ngroups = 4;
    proc.bsd.kp_eproc.e_ucred.cr_groups[0] = gid;
    proc.bsd.kp_eproc.e_ucred.cr_groups[1] = 250;
    proc.bsd.kp_eproc.e_ucred.cr_groups[2] = 286;
    proc.bsd.kp_eproc.e_ucred.cr_groups[3] = 299;
    proc.bsd.kp_eproc.e_ppid = ppid;
    proc.bsd.kp_eproc.e_pgid = ppid;
    proc.bsd.kp_eproc.e_tdev = -1;
    proc.bsd.kp_eproc.e_flag = 2;
    
    // Adding/Inserting proc
    return proc_insert_proc(proc);
}

ksurface_error_t proc_add_child_proc(pid_t ppid,
                                     pid_t pid,
                                     NSString *executablePath)
{
    // Get the old process
    ksurface_proc_t proc = {};
    ksurface_error_t error = proc_for_pid(ppid, &proc);
    if(error != kSurfaceErrorSuccess)
    {
        return error;
    }
    
    // Overwriting executable path
    strncpy(proc.path, [[[NSURL fileURLWithPath:executablePath] path] UTF8String], PATH_MAX);
    strncpy(proc.bsd.kp_proc.p_comm, [[[NSURL fileURLWithPath:executablePath] lastPathComponent] UTF8String], MAXCOMLEN + 1);
    
    // Patching the old process structure we copied out of the process table
    proc_setpid(proc, pid);
    
    // Insert it back
    return proc_insert_proc(proc);
}
