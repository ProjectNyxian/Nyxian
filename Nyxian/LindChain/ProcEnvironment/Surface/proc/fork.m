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
    if(ksurface == NULL ||
       parent == NULL)
    {
        return NULL;
    }
    
    /* creating a safe to use copy of the parent */
    ksurface_proc_copy_t *parent_copy = proc_copy_for_proc(parent, kProcCopyOptionRetainedCopy);
    
    /* null pointer check */
    if(parent_copy == NULL)
    {
        return NULL;
    }
    
    /* creating child process */
    ksurface_proc_t *child = proc_create_from_proc_copy(parent_copy);
    
    /* null pointer check */
    if(child == NULL)
    {
        /* destroying the copy of the parent that references the parent */
        proc_copy_destroy(parent_copy);
        return NULL;
    }
    
    /* setting child process properties */
    proc_setpid(child, child_pid);
    proc_setppid(child, proc_getpid(parent_copy));
    
    /* checking if parent process is kernel_proc_ */
    if(parent_copy->proc == kernel_proc_)
    {
        /* dropping permitives to the movile user */
        proc_setmobilecred(child);
    }
    
    /* checking if the parent process got PEEntitlementProcessSpawnInheriteEntitlements */
    if(!entitlement_got_entitlement(proc_getentitlements(parent_copy), PEEntitlementProcessSpawnInheriteEntitlements))
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
        strlcpy(child->kproc.kcproc.nyx.executable_path, path, PATH_MAX);
        
        /* FIXME: argv[0] shall be used for p_comm and not the last path component */
        const char *name = strrchr(path, '/');
        name = name ? name + 1 : path;
        strlcpy(child->kproc.kcproc.bsd.kp_proc.p_comm, name, MAXCOMLEN);
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
    
    /*
     * referencing parent first, to
     * first of all prevent a reference leak
     * and second of all dont waste cpu cycles
     * this is basically the part where we
     * tell the parent who their child is
     * and the child who their parent is
     * and create a reference contract.
     */
    if(!proc_retain(parent))
    {
    out_parent_contract_retain_failed:
        proc_remove_by_pid(proc_getpid(child));
        proc_copy_destroy(parent_copy);
        return NULL;
    }
    
    /* locking children structure */
    pthread_mutex_lock(&(parent->kproc.children.mutex));
    
    /*
     * checking if it would exceed maximum amount
     * of child processes per process.
     */
    if(parent->kproc.children.children_cnt >= CHILD_PROC_MAX || !proc_retain(child))
    {
        /* unlocking parent mutex again */
        pthread_mutex_unlock(&(parent->kproc.children.mutex));
        
        /* releasing all references */
        proc_release(parent);
        goto out_parent_contract_retain_failed;
        
        /* got nothing for you */
        return NULL;
    }
    
    /* locking children structure numero two */
    pthread_mutex_lock(&(child->kproc.children.mutex));
    
    /* performing contract */
    child->kproc.children.parent = parent;
    child->kproc.children.parent_cld_idx = parent->kproc.children.children_cnt++;
    parent->kproc.children.children[child->kproc.children.parent_cld_idx] = child;
    
    /*
     * okay both parties signed the contract so now
     * releasing both locks we currently hold.
     */
    pthread_mutex_unlock(&(child->kproc.children.mutex));
    pthread_mutex_unlock(&(parent->kproc.children.mutex));
    
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
    pthread_mutex_lock(&(proc->kproc.children.mutex));
    
    /* killing all children of the exiting process */
    while(proc->kproc.children.children_cnt > 0)
    {
        /* get index of last child */
        uint64_t idx = proc->kproc.children.children_cnt - 1;
        ksurface_proc_t *child = proc->kproc.children.children[idx];
        
        /* retaining child */
        if(!proc_retain(child))
        {
            /* in case we cannot retain the child, we skip the child */
            continue;
        }
        
        /* unlocking our mutex */
        pthread_mutex_unlock(&(proc->kproc.children.mutex));
        
        /* calling exit on the child */
        proc_exit(child);
        
        /* releasing reference previously retained */
        proc_release(child);
        
        /* relocking */
        pthread_mutex_lock(&(proc->kproc.children.mutex));
    }
    
    /* lock */
    pthread_mutex_unlock(&(proc->kproc.children.mutex));
    
    /* remove from parent */
    ksurface_proc_t *parent = proc->kproc.children.parent;
    
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
        pthread_mutex_lock(&(parent->kproc.children.mutex));
        pthread_mutex_lock(&(proc->kproc.children.mutex));
        
        uint64_t my_idx = proc->kproc.children.parent_cld_idx;
        uint64_t last_idx = parent->kproc.children.children_cnt - 1;
        
        /* swap with last if needed */
        if(my_idx != last_idx)
        {
            ksurface_proc_t *last_proc = parent->kproc.children.children[last_idx];
            
            pthread_mutex_lock(&(last_proc->kproc.children.mutex));
            parent->kproc.children.children[my_idx] = last_proc;
            last_proc->kproc.children.parent_cld_idx = my_idx;
            pthread_mutex_unlock(&(last_proc->kproc.children.mutex));
        }
        
        /* clear slot and decrement */
        parent->kproc.children.children[last_idx] = NULL;
        parent->kproc.children.children_cnt--;
        
        /* clear our parent reference */
        proc->kproc.children.parent = NULL;
        proc->kproc.children.parent_cld_idx = 0;
        
        pthread_mutex_unlock(&(proc->kproc.children.mutex));
        pthread_mutex_unlock(&(parent->kproc.children.mutex));
        
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
