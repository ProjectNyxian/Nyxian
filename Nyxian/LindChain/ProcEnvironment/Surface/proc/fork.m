/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 cr4zyengineer

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#import <LindChain/ProcEnvironment/Surface/proc/fork.h>
#import <LindChain/ProcEnvironment/Surface/proc/insert.h>
#import <LindChain/ProcEnvironment/Surface/proc/def.h>
#import <LindChain/Services/trustd/LDETrust.h>
#import <LindChain/ProcEnvironment/Utils/klog.h>
#import <LindChain/ProcEnvironment/Surface/proc/remove.h>
#import <LindChain/Multitask/ProcessManager/LDEProcessManager.h>


ksurface_proc_t *proc_fork(ksurface_proc_t *parent,
                           pid_t child_pid,
                           const char *path)
{
    /* null pointer check */
    if(parent == NULL ||
       path == NULL)
    {
        return NULL;
    }
    
    /* creating child process */
    ksurface_proc_t *child = kvo_copy(parent);

    /* checking if child is null */
    if(child == NULL)
    {
        return NULL;
    }
    
    /* setting child process properties */
    proc_setppid(child, proc_getpid(child));    /* currently we are a safe to use perfect copy of the parent anyways */
    proc_setpid(child, child_pid);
    
    /*
     * getting additional process entitlements
     * from trust cache. if it got PEEntitlementPlatform
     * we abort the spawn... in case the process spawning wasnt the kernel
     * or a platform process. platform binaries may only be spawned by other
     * platform binaries, user allowed platform binaries also count.
     */
    PEEntitlement entitlement = [[LDETrust shared] entitlementsOfExecutableAtPath:[NSString stringWithCString:path encoding:NSUTF8StringEncoding]];
    PEEntitlement currentEntitlement = proc_getentitlements(child);
    
    if(entitlement_got_entitlement(entitlement, PEEntitlementPlatform) &&
       !entitlement_got_entitlement(currentEntitlement, PEEntitlementPlatform))
    {
        kvo_release(child);
        return NULL;
    }
    
    /* checking if parent process is the kernel process */
    if(parent == kernel_proc_)
    {
        /*
         * dropping permitives to the permitives
         * of a standard userspace program, means
         * entitlements from trustcache, mobile user
         * and so on, but dont worry, although daemons
         * initially start as mobile, there is no race
         * condition because they have platform
         * entitlement.
         */
        proc_setmobilecred(child);                          /* dropping ucred permitives */
        proc_setsid(child, child_pid);                      /* forcing its own process identifier as session identifier */
        goto force_not_inherite_entitlements;               /* forcing none, so it gets fresh entitlements from trustcache */
    }
    
    /*
     * process can decide if they want to inherite entitlements or not.
     */
    if(!entitlement_got_entitlement(currentEntitlement, PEEntitlementProcessSpawnInheriteEntitlements))
force_not_inherite_entitlements:
    {
        /* not allowed/not willing to inherite */
        currentEntitlement = PEEntitlementNone;
    }
    else
    {
        /* checking for platform status */
        if(entitlement_got_entitlement(currentEntitlement, PEEntitlementPlatform))
        {
            /* platform processes, cannot inherite platformisation */
            currentEntitlement &= ~PEEntitlementPlatform;
        }
        else
        {
            /* none platform processes, cannot inherite those */
            currentEntitlement &= ~PEEntitlementTaskForPid;
            currentEntitlement &= ~PEEntitlementProcessElevate;
            currentEntitlement &= ~PEEntitlementTrustCacheWrite;
        }
    }
    
    /* now we add the ones from trust cache */
    PEEntitlement combined_entitlement = currentEntitlement | entitlement;
    proc_setentitlements(child, combined_entitlement);
    proc_setmaxentitlements(child, combined_entitlement);
    
    /* copying the path */
    strlcpy(child->nyx.executable_path, path, PATH_MAX);
        
    /* FIXME: argv[0] shall be used for p_comm and not the last path component */
    const char *name = strrchr(path, '/');
    name = name ? name + 1 : path;
    strlcpy(child->bsd.kp_proc.p_comm, name, MAXCOMLEN + 1);
    
    /* insert will retain the child process */
    if(proc_insert(child) != SURFACE_SUCCESS)
    {
        /* logging if enabled */
        klog_log(@"proc:fork", @"[%d] fork failed process %p failed to be inserted", proc_getpid(child), child);
        
        /* releasing child process because of failed insert */
        kvo_release(child);
        return NULL;
    }
    
    /*
     * referencing parent first, to
     * first of all prevent a reference leak
     * and second of all dont waste cpu cycles
     * this is basically the part where we
     * tell the parent who their child is
     * and the child who their parent is
     * and create a reference contract.
     */
    if(!kvo_retain(parent))
out_parent_contract_retain_failed:
    {
        proc_remove_by_pid(proc_getpid(child));
        return NULL;
    }
    
    /* locking children structure */
    pthread_mutex_lock(&(parent->children.mutex));
    
    /*
     * checking if it would exceed maximum amount
     * of child processes per process.
     */
    if(parent->children.children_cnt >= CHILD_PROC_MAX || !kvo_retain(child))
    {
        /* unlocking parent mutex again */
        pthread_mutex_unlock(&(parent->children.mutex));
        
        /* releasing all references */
        kvo_release(parent);
        
        /* does already return */
        goto out_parent_contract_retain_failed;
    }
    
    /* locking children structure numero two */
    pthread_mutex_lock(&(child->children.mutex));
    
    /* performing contract */
    child->children.parent = parent;
    child->children.parent_cld_idx = parent->children.children_cnt++;
    parent->children.children[child->children.parent_cld_idx] = child;
    
    /*
     * okay both parties signed the contract so now
     * releasing both locks we currently hold.
     */
    pthread_mutex_unlock(&(child->children.mutex));
    pthread_mutex_unlock(&(parent->children.mutex));
    
    /* child stays retained for the caller */
    return child;
}

ksurface_return_t proc_exit(ksurface_proc_t *proc)
{
    /* null pointer check */
    if(proc == NULL)
    {
        return SURFACE_NULLPTR;
    }
    
    /* checking if proc is kernel */
    if(proc == kernel_proc_)
    {
        klog_log(@"proc:exit", @"cannot terminate the kernel");
        return SURFACE_DENIED;
    }
    
    /* retain process that wants to exit */
    if(!kvo_retain(proc))
    {
        return SURFACE_FAILED;
    }
    
    /* lock mutex */
    pthread_mutex_lock(&(proc->children.mutex));
    
    /* killing all children of the exiting process */
    while(proc->children.children_cnt > 0)
    {
        /* get index of last child */
        uint64_t idx = proc->children.children_cnt - 1;
        ksurface_proc_t *child = proc->children.children[idx];
        
        /* retaining child */
        if(!kvo_retain(child))
        {
            /* in case we cannot retain the child, we skip the child */
            continue;
        }
        
        /* unlocking our mutex */
        pthread_mutex_unlock(&(proc->children.mutex));
        
        /* calling exit on the child */
        proc_exit(child);
        
        /* releasing reference previously retained */
        kvo_release(child);
        
        /* relocking */
        pthread_mutex_lock(&(proc->children.mutex));
    }
    
    /* unlock */
    pthread_mutex_unlock(&(proc->children.mutex));
    
    /* remove from parent */
    ksurface_proc_t *parent = proc->children.parent;
    
    /* null pointer checking parent */
    if(parent != NULL)
    {
        /* retaining the parent */
        if(!kvo_retain(parent))
        {
            /* releasing child */
            kvo_release(proc);
            return SURFACE_FAILED;
        }
        
        /* lock order: parent → child */
        pthread_mutex_lock(&(parent->children.mutex));
        pthread_mutex_lock(&(proc->children.mutex));
        
        uint64_t my_idx = proc->children.parent_cld_idx;
        uint64_t last_idx = parent->children.children_cnt - 1;
        
        /* swap with last if needed */
        if(my_idx != last_idx)
        {
            ksurface_proc_t *last_proc = parent->children.children[last_idx];
            
            pthread_mutex_lock(&(last_proc->children.mutex));
            parent->children.children[my_idx] = last_proc;
            last_proc->children.parent_cld_idx = my_idx;
            pthread_mutex_unlock(&(last_proc->children.mutex));
        }
        
        /* clear slot and decrement */
        parent->children.children[last_idx] = NULL;
        parent->children.children_cnt--;
        
        /* clear our parent reference */
        proc->children.parent = NULL;
        proc->children.parent_cld_idx = 0;
        
        pthread_mutex_unlock(&(proc->children.mutex));
        pthread_mutex_unlock(&(parent->children.mutex));
        
        /* release relationship references */
        kvo_release(proc);
        kvo_release(parent);
        
        /* release working ref */
        kvo_release(parent);
    }
    
    pid_t pid = proc_getpid(proc);
    
    /* TODO: Completely move to tree-based system, which is possible now */
    proc_remove_by_pid(pid);  /* remove from global table */
    
    /* release our working reference */
    kvo_release(proc);
    
    /* terminate process */
    LDEProcess *process = [[LDEProcessManager shared].processes objectForKey:@(pid)];
    if(process != NULL)
    {
        [process terminate];
    }
    
    return SURFACE_SUCCESS;
}

ksurface_return_t proc_zombify(ksurface_proc_t *proc)
{
    /* null pointer check */
    if(proc == NULL)
    {
        return SURFACE_NULLPTR;
    }
    
    /* checking if proc is kernel */
    if(proc == kernel_proc_)
    {
        klog_log(@"proc:exit", @"cannot zombify the kernel");
        return SURFACE_DENIED;
    }
    
    /* retain process that wants to be zombified */
    if(!kvo_retain(proc))
    {
        return SURFACE_FAILED;
    }
    
    pthread_mutex_lock(&(proc->children.mutex));
    
    /* killing all children of the exiting process */
    while(proc->children.children_cnt > 0)
    {
        /* get index of last child */
        uint64_t idx = proc->children.children_cnt - 1;
        ksurface_proc_t *child = proc->children.children[idx];
        
        /* retaining child */
        if(!kvo_retain(child))
        {
            /* in case we cannot retain the child, we skip the child */
            continue;
        }
        
        /*
         * have to unlock it so proc_exit can claim the lock
         * on the recurse. as its needed to zombify all processes
         * underneath.
         */
        pthread_mutex_unlock(&(proc->children.mutex));
        proc_exit(child);
        kvo_release(child);
        pthread_mutex_lock(&(proc->children.mutex));
    }
    
    /* when parent is the kernel dont zombify, kill immediately */
    if(proc->children.parent == kernel_proc_)
    {
        pthread_mutex_unlock(&(proc->children.mutex));
        kvo_release(proc);
        proc_exit(proc);
        return SURFACE_SUCCESS;
    }
    
    pthread_mutex_unlock(&(proc->children.mutex));
    
    /* mark as zombified */
    kvo_wrlock(proc);
    proc->bsd.kp_proc.p_stat = SZOMB;
    kvo_event_trigger(proc, kvObjEventCustom2, 0);
    kvo_unlock(proc);
    kvo_release(proc);
    
    return SURFACE_SUCCESS;
}
