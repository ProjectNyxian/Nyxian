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
#import <LindChain/ProcEnvironment/Process/PEProcessManager.h>

ksurface_proc_t *proc_fork(ksurface_proc_t *parent,
                           pid_t child_pid,
                           const char *path)
{
    assert(parent != NULL && path != NULL);
    
    ksurface_proc_t *child = kvo_copy(parent);
    
    if(child == NULL)
    {
        return NULL;
    }
    
    /*
     * setting child process identifiers
     * which are safe to change now, such
     * as the ppid, the ppid becomes the pid
     * because the ppid is the pid of the copy
     * and the copy is the copy of the parent.
     */
    proc_setppid(child, proc_getpid(child));
    proc_setpid(child, child_pid);  /* function passed pid of child */
    
    /*
     * getting the entitlements passed of the
     * executables code signature blob if
     * applicable. if signed correctly it
     * will return the entitlements of
     * sayed executable.
     */
    PEEntitlement entitlement = [[LDETrust shared] entitlementsOfExecutableAtPath:[NSString stringWithCString:path encoding:NSUTF8StringEncoding]];
    PEEntitlement currentEntitlement = proc_getentitlements(child);
    PEEntitlement currentMaxEntitlement = proc_getmaxentitlements(child);
    
    /*
     * only a platform process, may be able to
     * spawn a other platform process otherwise
     * this would be exploitable. so we strip away
     * all entitlements the parent process doesnt
     * have in case it is non platform and setting
     * currentEntitlement to entitlement.
     */
    if(!entitlement_got_entitlement(currentMaxEntitlement, PEEntitlementPlatform))
    {
        /*
         * child gets nothing extra, removing
         * what parent doesnt have.
         */
        entitlement &= currentEntitlement;
    }
    
    /*
     * checking if parent process is the kernel
     * process, because the kernel process
     * regardless of what its own entitlements
     * are shall drop the entitlements of the
     * child process and force a new session id
     * and ucred. this is also to prevent a attack
     * to change the kernels entitlements with
     * a vulnerability and then escalate it by
     * making it spawn process with entitlement
     * inheritence as code on iOS has to be signed
     * a attacker cannot change this would causing
     * ksurface to crash.
     */
    if(parent == kernel_proc_)
    {
        proc_setmobilecred(child);                          /* dropping ucred permitives */
        proc_setsid(child, child_pid);                      /* forcing its own process identifier as session identifier */
        goto force_not_inherite_entitlements;               /* forcing none, so it gets fresh entitlements from the executable */
    }
    
    /* process can decide if they want to inherite entitlements or not */
    if(entitlement_got_entitlement(currentEntitlement, PEEntitlementProcessSpawnInheriteEntitlements))
    {
        /*
         * entitlements which shall be stripped regardless
         * of who spawns the process as these entitlements
         * are way too powerful.. if a process spawns and
         * wants to debug they need to spawn the child process
         * or debug a process in the same session.
         */
        currentEntitlement &= ~(PEEntitlementPlatform | PEEntitlementTaskForPid | PEEntitlementProcessElevate);
    }
    else
force_not_inherite_entitlements:
    {
        currentEntitlement = PEEntitlementNone;
    }
    
    /*
     * now combining the current eneitlements
     * and the entitlements of the executable.
     */
    PEEntitlement combined_entitlement = currentEntitlement | entitlement;
    proc_setentitlements(child, combined_entitlement);
    proc_setmaxentitlements(child, combined_entitlement);
    
    /* copying the executables path */
    strlcpy(child->nyx.executable_path, path, PATH_MAX);
        
    /* FIXME: argv[0] shall be used for p_comm and not the last path component */
    const char *name = strrchr(path, '/');
    name = name ? name + 1 : path;
    strlcpy(child->bsd.kp_proc.p_comm, name, MAXCOMLEN + 1);
    
    /* insert will retain the child process */
    if(proc_insert(child) != SURFACE_SUCCESS)
    {
        klog_log("proc:fork", "[%d] fork failed process %p failed to be inserted", proc_getpid(child), child);
        
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
    {
        goto out_parent_contract_retain_failed;
    }
    
    pthread_mutex_lock(&(parent->children.mutex));
    
    /*
     * checking if it would exceed maximum amount
     * of child processes per process.
     */
    if(parent->children.children_cnt >= CHILD_PROC_MAX ||
       !kvo_retain(child))
    {
        pthread_mutex_unlock(&(parent->children.mutex));
        kvo_release(parent);
        
    out_parent_contract_retain_failed:
        proc_remove_by_pid(proc_getpid(child));
        return NULL;
    }
    
    pthread_mutex_lock(&(child->children.mutex));
    
    /* performing contract */
    child->children.parent = parent;
    child->children.parent_cld_idx = parent->children.children_cnt++;
    parent->children.children[child->children.parent_cld_idx] = child;
    
    pthread_mutex_unlock(&(child->children.mutex));
    pthread_mutex_unlock(&(parent->children.mutex));
    
    /* child stays retained for the caller */
    return child;
}

ksurface_return_t proc_reap(ksurface_proc_t *proc)
{
    assert(proc != NULL && proc != kernel_proc_);
    
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
        proc_reap(child);
        
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
    PEProcess *process = [[PEProcessManager shared] processForProcessIdentifier:pid];
    if(process != NULL)
    {
        [process terminate];
    }
    
    return SURFACE_SUCCESS;
}

ksurface_return_t proc_zombify(ksurface_proc_t *proc)
{
    assert(proc != NULL && proc != kernel_proc_);
    
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
        proc_reap(child);
        kvo_release(child);
        pthread_mutex_lock(&(proc->children.mutex));
    }
    
    /* when parent is the kernel dont zombify, reap immediately */
    if(proc->children.parent == kernel_proc_)
    {
        pthread_mutex_unlock(&(proc->children.mutex));
        kvo_release(proc);
        proc_reap(proc);
        return SURFACE_SUCCESS;
    }
    
    pthread_mutex_unlock(&(proc->children.mutex));
    
    /* mark as zombified */
    kvo_wrlock(proc);
    proc->bsd.kp_proc.p_stat = SZOMB;
    kvo_unlock(proc);
    
    ksurface_proc_t *parent = NULL;
    ksurface_return_t ksr = proc_parent_for_proc(proc, &parent);
    
    if(ksr == SURFACE_SUCCESS)
    {
        kvo_event_trigger(parent, kvObjEventCustom0, (uintptr_t)proc);
        kvo_release(parent);
    }
    
    PEProcess *process = [[PEProcessManager shared] processForProcessIdentifier:proc_getpid(parent)];
    if(process != nil)
    {
        [process sendSignal:SIGCHLD];
    }
    
    kvo_release(proc);
    
    return SURFACE_SUCCESS;
}

ksurface_return_t proc_state_change(ksurface_proc_t *proc,
                                    int64_t status)
{
    ksurface_proc_t *parent = NULL;
    ksurface_return_t ksr = proc_parent_for_proc(proc, &parent);
    
    if(ksr != SURFACE_SUCCESS)
    {
        return ksr;
    }
    
    pthread_mutex_lock(&(parent->children.mutex));
    proc->nyx.p_status = status;
    pthread_mutex_unlock(&(parent->children.mutex));
    
    kvo_event_trigger(parent, kvObjEventCustom0, (uintptr_t)proc);
    
    PEProcess *process = [[PEProcessManager shared] processForProcessIdentifier:proc_getpid(parent)];
    if(process != nil)
    {
        [process sendSignal:SIGCHLD];
    }
    
    kvo_release(parent);
    return SURFACE_SUCCESS;
}
