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

#import <LindChain/ProcEnvironment/Surface/proc/new.h>
#import <LindChain/ProcEnvironment/Surface/proc/def.h>
#import <LindChain/ProcEnvironment/Surface/proc/append.h>
#import <LindChain/ProcEnvironment/Surface/proc/replace.h>
#import <LindChain/ProcEnvironment/Surface/proc/fetch.h>
#import <LindChain/Services/trustd/LDETrust.h>
#import <LindChain/ProcEnvironment/Server/Trust.h>

ksurface_error_t proc_new_proc(pid_t ppid,
                               pid_t pid,
                               uid_t uid,
                               gid_t gid,
                               NSString *executablePath)
{
#ifdef HOST_ENV
    ksurface_proc_t proc = {};
    
    // Set ksurface_proc properties
    proc.nyx.force_task_role_override = true;
    proc.nyx.task_role_override = TASK_UNSPECIFIED;
    strncpy(proc.nyx.executable_path, [[[NSURL fileURLWithPath:executablePath] path] UTF8String], PATH_MAX);
    
    if(ppid == PID_LAUNCHD)
    {
        // Its nyxian it self
        proc_setentitlements(proc, PEEntitlementAll);
    }
    else if([executablePath isEqualToString:@"/usr/libexec/installd"] ||
            [executablePath isEqualToString:@"/usr/libexec/trustd"])
    {
        // Its a daemon
        proc_setentitlements(proc, PEEntitlementSystemApplication);
    }
    else
    {
        // Its a usual process nyxian created
        NSString *entHash = [LDETrust entHashOfExecutableAtPath:executablePath];
        if(entHash == nil)
        {
            proc_setentitlements(proc, PEEntitlementSandboxedApplication);
        }
        else
        {
            proc_setentitlements(proc, [[TrustCache shared] getEntitlementsForHash:entHash]);
        }
    }
    
    // Set bsd process stuff
    if(gettimeofday(&proc.bsd.kp_proc.p_un.__p_starttime, NULL) != 0) return kSurfaceErrorUndefined;
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
    return proc_append(proc);
#else
    return kSurfaceErrorUndefined;
#endif /* HOST_ENV */
}

ksurface_error_t proc_new_child_proc(pid_t ppid,
                                     pid_t pid,
                                     NSString *executablePath)
{
#ifdef HOST_ENV
    reflock_lock(&(surface->reflock));
    
    // Get the old process
    ksurface_proc_t proc = {};
    ksurface_error_t error = proc_for_pid(ppid, &proc);
    if(error != kSurfaceErrorSuccess)
    {
        reflock_unlock(&(surface->reflock));
        return error;
    }
    
    // Reset time to now
    if(gettimeofday(&proc.bsd.kp_proc.p_un.__p_starttime, NULL) != 0)
    {
        reflock_unlock(&(surface->reflock));
        return kSurfaceErrorUndefined;
    }
    
    // Inheriting entitlements or not?
    if(!entitlement_got_entitlement(proc_getentitlements(proc), PEEntitlementProcessSpawnInheriteEntitlements))
    {
        NSString *entHash = [LDETrust entHashOfExecutableAtPath:executablePath];
        if(entHash == nil)
        {
            proc_setentitlements(proc, PEEntitlementSandboxedApplication);
        }
        else
        {
            proc_setentitlements(proc, [[TrustCache shared] getEntitlementsForHash:entHash]);
        }
    }
    
    // Overwriting executable path
    strncpy(proc.nyx.executable_path, [[[NSURL fileURLWithPath:executablePath] path] UTF8String], PATH_MAX);
    strncpy(proc.bsd.kp_proc.p_comm, [[[NSURL fileURLWithPath:executablePath] lastPathComponent] UTF8String], MAXCOMLEN + 1);
    
    // Patching the old process structure we copied out of the process table
    proc_setppid(proc, ppid);
    proc_setpid(proc, pid);
    
    // Insert it back
    error = proc_append(proc);
    
    reflock_unlock(&(surface->reflock));
    
    return error;
#else /* HOST_ENV */
    return kSurfaceErrorUndefined;
#endif
}
