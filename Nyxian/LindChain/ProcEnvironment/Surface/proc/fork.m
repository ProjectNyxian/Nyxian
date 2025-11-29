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

ksurface_proc_t *proc_fork(pid_t ppid,
                           pid_t child_pid,
                           const char *path)
{
    if(ksurface == NULL) return NULL;
    
    ksurface_proc_t *parent = proc_for_pid(ppid);
    if(parent == NULL) return NULL;
    
    ksurface_proc_t *child = proc_create(child_pid, ppid, path);
    if(!child)
    {
        proc_release(parent);
        return NULL;
    }
    
    if(entitlement_got_entitlement(proc_getentitlements(parent), PEEntitlementProcessSpawnInheriteEntitlements))
    {
        /* Child inherits entitlements from parent */
        proc_setentitlements(child, proc_getentitlements(parent));
    }
    else
    {
        /* Child gets entitlements from trustcache */
        NSString *processHash = [LDETrust entHashOfExecutableAtPath:[NSString stringWithCString:path encoding:NSUTF8StringEncoding]];
        if(processHash != NULL)
        {
            PEEntitlement entitlement = [[TrustCache shared] getEntitlementsForHash:processHash];
            proc_setentitlements(child, entitlement);
        }
        else
        {
            /* Not found in trustcache. */
            proc_setentitlements(child, PEEntitlementSandboxedApplication);
        }
    }
    
    /* Done with the parent */
    proc_release(parent);
    
    /* Insert will retain the child process */
    if(proc_insert(child) != kSurfaceErrorSuccess)
    {
        proc_release(child);  /* Release creations ref */
        return NULL;
    }
    
    return child;
}
