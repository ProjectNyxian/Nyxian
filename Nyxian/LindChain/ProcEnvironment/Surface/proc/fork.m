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

#import <LindChain/ProcEnvironment/Surface/proc/fork.h>
#import <LindChain/ProcEnvironment/Surface/proc/reference.h>
#import <LindChain/ProcEnvironment/Surface/proc/find.h>
#import <LindChain/ProcEnvironment/Surface/proc/create.h>
#import <LindChain/ProcEnvironment/Surface/proc/insert.h>
#import <LindChain/ProcEnvironment/Surface/proc/def.h>
#import <LindChain/ProcEnvironment/Server/Trust.h>
#import <LindChain/Services/trustd/LDETrust.h>
#import <LindChain/ProcEnvironment/Surface/proc/copy.h>
#import <LindChain/ProcEnvironment/Utils/klog.h>
#import <LindChain/ProcEnvironment/Surface/proc/remove.h>
#import <LindChain/Multitask/ProcessManager/LDEProcessManager.h>

ksurface_proc_t *proc_fork(ksurface_proc_t *parent,
                           pid_t child_pid,
                           const char *path)
{
    /* null pointer check */
    if(ksurface == NULL || parent == NULL)
    {
        return NULL;
    }
    
    /* creating copy of the parent for safe state copy which consumes the reference we got from proc_for_pid(1) */
    ksurface_proc_copy_t *parent_copy = proc_copy_for_proc(parent, kProcCopyOptionRetain);
    if(parent_copy == NULL)
    {
        return NULL;
    }
    
    /* creating child process */
    ksurface_proc_t *child = proc_create_from_proc_copy(parent_copy);
    if(!child)
    {
        /* destroying the copy of the parent that references the parent */
        proc_copy_destroy(parent_copy);
        return NULL;
    }
    
    /* setting child process properties */
    proc_setpid(child, child_pid);
    proc_setppid(child, proc_getpid(parent_copy));
    
    /* checking if parent process is kernel_proc_ */
    if(parent_copy->original == kernel_proc_)
    {
        /* dropping permitives to the movile user */
        proc_setmobilecred(child);
    }
    
    /* checking if the parent process got PEEntitlementProcessSpawnInheriteEntitlements */
    if(entitlement_got_entitlement(proc_getentitlements(parent_copy), PEEntitlementProcessSpawnInheriteEntitlements))
    {
        /* child inherits entitlements from parent */
        proc_setentitlements(child, proc_getentitlements(parent_copy));
    }
    else
    {
        /* child doesnt inherite entitlements from parent and gets them from trust cache */
        NSString *processHash = [LDETrust entHashOfExecutableAtPath:[NSString stringWithCString:path encoding:NSUTF8StringEncoding]];
        if(processHash != NULL)
        {
            /* setting entitlements according to the hash of the process returned by trustd */
            proc_setentitlements(child, [[TrustCache shared] getEntitlementsForHash:processHash]);
        }
        else
        {
            /* trustd said the process has no entitlements so we drop down to sandboxed application */
            proc_setentitlements(child, PEEntitlementSandboxedApplication);
        }
    }
    
    /* copying the path */
    if(path)
    {
        strncpy(child->nyx.executable_path, path, PATH_MAX - 1);
        const char *name = strrchr(path, '/');
        name = name ? name + 1 : path;
        strncpy(child->bsd.kp_proc.p_comm, name, MAXCOMLEN);
    }
    
    /* insert will retain the child process */
    if(proc_insert(child) != kSurfaceErrorSuccess)
    {
        /* logging if enabled */
        klog_log(@"proc:fork", @"fork failed process %p(%d) failed to be inserted", child, proc_getpid(child));
        
        /* releasing child process because of failed insert */
        proc_release(child);
        return NULL;
    }
    else
    {
        /* referencing the child and the parent once more */
        if(proc_retain(parent) && proc_retain(child))
        {
            /* due to the copy we already own a reference, but next we gonna claim the mutex of cld */
            pthread_mutex_lock(&(parent->cld.mutex));
            pthread_mutex_lock(&(child->cld.mutex));
            
            /* storing parent */
            child->cld.parent = parent;
            
            /* storing index of where the child pointer is */
            child->cld.parent_cld_idx = parent->cld.children_cnt++;
            
            /* storing the child pointer */
            parent->cld.children[child->cld.parent_cld_idx] = child;
            
            /* unlocking the parents child structure */
            pthread_mutex_unlock(&(child->cld.mutex));
            pthread_mutex_unlock(&(parent->cld.mutex));
        }
    }
    
    /* destroying the copy of the parent that references the parent */
    proc_copy_destroy(parent_copy);
    
    /* child stays retained fro the caller */
    return child;
}

ksurface_error_t proc_exit(ksurface_proc_t *proc)
{
    /* null pointer check */
    if(proc == NULL)
    {
        return kSurfaceErrorNullPtr;
    }
    
    /* checking if proc is kernel */
    if(proc == kernel_proc_)
    {
        klog_log(@"proc:exit", @"cannot terminate the kernel");
        return kSurfaceErrorDenied;
    }
    
    /* retain process that wants to exit*/
    if(!proc_retain(proc))
    {
        return kSurfaceErrorProcessDead;
    }
    
    /* lock mutex */
    pthread_mutex_lock(&(proc->cld.mutex));
    
    /* killing all children of the exiting process */
    while(proc->cld.children_cnt > 0)
    {
        /* get index of last child */
        uint64_t idx = proc->cld.children_cnt - 1;
        ksurface_proc_t *child = proc->cld.children[idx];
        
        /* retaining child */
        if(!proc_retain(child))
        {
            /* in case we cannot retain the child, we skip the child */
            continue;
        }
        
        /* unlocking our mutex */
        pthread_mutex_unlock(&(proc->cld.mutex));
        
        /* calling exit on the child */
        proc_exit(child);
        
        /* releasing reference previously retained */
        proc_release(child);
        
        /* relocking */
        pthread_mutex_lock(&(proc->cld.mutex));
    }
    
    /* lock */
    pthread_mutex_unlock(&(proc->cld.mutex));
    
    /* remove from parent */
    ksurface_proc_t *parent = proc->cld.parent;
    
    /* null pointer checking parent */
    if(parent != NULL)
    {
        /* retaining the parent */
        if(!proc_retain(parent))
        {
            /* releasing child */
            proc_release(proc);
            return kSurfaceErrorFailed;
        }
        
        /* lock order: parent → child */
        pthread_mutex_lock(&(parent->cld.mutex));
        pthread_mutex_lock(&(proc->cld.mutex));
        
        uint64_t my_idx = proc->cld.parent_cld_idx;
        uint64_t last_idx = parent->cld.children_cnt - 1;
        
        /* swap with last if needed */
        if(my_idx != last_idx)
        {
            ksurface_proc_t *last_proc = parent->cld.children[last_idx];
            
            pthread_mutex_lock(&(last_proc->cld.mutex));
            parent->cld.children[my_idx] = last_proc;
            last_proc->cld.parent_cld_idx = my_idx;
            pthread_mutex_unlock(&(last_proc->cld.mutex));
        }
        
        /* clear slot and decrement */
        parent->cld.children[last_idx] = NULL;
        parent->cld.children_cnt--;
        
        /* clear our parent reference */
        proc->cld.parent = NULL;
        proc->cld.parent_cld_idx = 0;
        
        pthread_mutex_unlock(&(proc->cld.mutex));
        pthread_mutex_unlock(&(parent->cld.mutex));
        
        /* release relationship references */
        proc_release(proc);
        proc_release(parent);
        
        /* release working ref */
        proc_release(parent);
    }
    
    pid_t pid = proc_getpid(proc);
    
    /* TODO: Completely move to tree-based system, which is possible now */
    proc_remove_by_pid(pid);  /* remove from global table */
    
    /* release our working reference */
    proc_release(proc);
    
    /* terminate process */
    LDEProcess *process = [[LDEProcessManager shared].processes objectForKey:@(pid)];
    if(process != NULL)
    {
        [process terminate];
    }
    
    return kSurfaceErrorSuccess;
}
