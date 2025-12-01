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
    
    /* destroying the copy of the parent that references the parent */
    proc_copy_destroy(parent_copy);
    
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
    
    /* child stays retained fro the caller */
    return child;
}
