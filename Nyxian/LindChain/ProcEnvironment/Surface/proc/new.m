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
#import <LindChain/ProcEnvironment/panic.h>
#import <LindChain/ProcEnvironment/Utils/klog.h>

ksurface_error_t proc_init_kproc(void)
{
#ifdef HOST_ENV
    reflock_lock(&(surface->reflock));
    
    klog_log(@"proc:kproc", @"initilizing kernel process");
    
    if(surface->proc_info.proc_count != 0)
    {
        // Its not nyxian adding it self to the list... This shall never happen under no condition
        environment_panic();
        
        // Incase we return from panic... which shall never happen under no condition
        reflock_unlock(&(surface->reflock));
        return kSurfaceErrorUndefined;
    }
    
    ksurface_proc_t proc = {};
    
    // Set ksurface_proc properties
    proc.nyx.force_task_role_override = true;
    proc.nyx.task_role_override = TASK_UNSPECIFIED;
    NSString *executablePath = [[NSBundle mainBundle] executablePath];
    strncpy(proc.nyx.executable_path, [executablePath UTF8String], PATH_MAX);
    proc_setentitlements(proc, PEEntitlementKernel);
    klog_log(@"proc:kproc", @"setting kernel process entitlements to %lu", PEEntitlementKernel);
    
    // Set bsd process stuff
    if(gettimeofday(&proc.bsd.kp_proc.p_un.__p_starttime, NULL) != 0)
    {
        reflock_unlock(&(surface->reflock));
        return kSurfaceErrorUndefined;
    }
    proc.bsd.kp_proc.p_flag = P_LP64 | P_EXEC;
    proc.bsd.kp_proc.p_stat = SRUN;
    proc.bsd.kp_proc.p_pid = getpid();
    proc.bsd.kp_proc.p_oppid = PID_LAUNCHD;
    proc.bsd.kp_proc.p_priority = PUSER;
    proc.bsd.kp_proc.p_usrpri = PUSER;
    strncpy(proc.bsd.kp_proc.p_comm, [[executablePath lastPathComponent] UTF8String], MAXCOMLEN + 1);
    proc.bsd.kp_proc.p_acflag = 2;
    proc.bsd.kp_eproc.e_pcred.p_ruid = 0;
    proc.bsd.kp_eproc.e_pcred.p_svuid = 0;
    proc.bsd.kp_eproc.e_pcred.p_rgid = 0;
    proc.bsd.kp_eproc.e_pcred.p_svgid = 0;
    proc.bsd.kp_eproc.e_ucred.cr_ref = 5;
    proc.bsd.kp_eproc.e_ucred.cr_uid = 0;
    proc.bsd.kp_eproc.e_ucred.cr_ngroups = 4;
    proc.bsd.kp_eproc.e_ucred.cr_groups[0] = 0;
    proc.bsd.kp_eproc.e_ucred.cr_groups[1] = 250;
    proc.bsd.kp_eproc.e_ucred.cr_groups[2] = 286;
    proc.bsd.kp_eproc.e_ucred.cr_groups[3] = 299;
    proc.bsd.kp_eproc.e_ppid = PID_LAUNCHD;
    proc.bsd.kp_eproc.e_pgid = PID_LAUNCHD;
    proc.bsd.kp_eproc.e_tdev = -1;
    proc.bsd.kp_eproc.e_flag = 2;
    
    ksurface_error_t error = proc_append(proc);
    if(error == kSurfaceErrorSuccess)
    {
        klog_log(@"proc:kproc", @"successfully created kernel process in process table");
    }
    
    // Adding/Inserting proc
    reflock_unlock(&(surface->reflock));
    
    return error;
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
    
    klog_log(@"proc:new", @"pid %d requested creation of its child pid %d in the process table with executable path \"%@\"", ppid, pid, executablePath);
    
    // Get the old process
    ksurface_proc_t proc = {};
    ksurface_error_t error = proc_for_pid(ppid, &proc);
    if(error != kSurfaceErrorSuccess)
    {
        reflock_unlock(&(surface->reflock));
        return error;
    }
    
    klog_log(@"proc:new", @"found process structure of pid %d in table", ppid);
    
    // Check if Nyxian spawned it, if so, drop its permitives accordingly
    if(proc_getppid(proc) == PID_LAUNCHD)
    {
        klog_log(@"proc:new", @"dropping permitives of child process %d", pid);
        
        //Its Nyxian it self and due to that we have to drop permitives to mobile user
        proc_setuid(proc, 501);
        proc_setruid(proc, 501);
        proc_setsvuid(proc, 501);
        proc_setgid(proc, 501);
        proc_setrgid(proc, 501);
        proc_setsvgid(proc, 501);
    }
    
    // Inheriting entitlements or not?
    if(!entitlement_got_entitlement(proc_getentitlements(proc), PEEntitlementProcessSpawnInheriteEntitlements))
    {
        klog_log(@"proc:new", @"pid %d doesnt inherit entitlements of pid %d", pid, ppid);
        NSString *entHash = [LDETrust entHashOfExecutableAtPath:executablePath];
        if(entHash == nil)
        {
            klog_log(@"proc:new", @"no hash found for pid %d dropping entitlements to %lu", pid, PEEntitlementSandboxedApplication);
            proc_setentitlements(proc, PEEntitlementSandboxedApplication);
        }
        else
        {
            PEEntitlement entitlement = [[TrustCache shared] getEntitlementsForHash:entHash];
            klog_log(@"proc:new", @"hash found for pid %d setting entitlements to %lu", pid, entitlement);
            proc_setentitlements(proc, entitlement);
        }
    }
    
    // Reset time to now
    if(gettimeofday(&proc.bsd.kp_proc.p_un.__p_starttime, NULL) != 0)
    {
        klog_log(@"proc:new", @"failed to get time of the day");
        reflock_unlock(&(surface->reflock));
        return kSurfaceErrorUndefined;
    }
    
    // Overwriting executable path
    strncpy(proc.nyx.executable_path, [[[NSURL fileURLWithPath:executablePath] path] UTF8String], PATH_MAX);
    strncpy(proc.bsd.kp_proc.p_comm, [[[NSURL fileURLWithPath:executablePath] lastPathComponent] UTF8String], MAXCOMLEN + 1);
    
    // Patching the old process structure we copied out of the process table
    proc_setppid(proc, ppid);
    proc_setpid(proc, pid);
    
    // Insert it back
    klog_log(@"proc:new", @"Inserting process structure of pid %d", pid);
    error = proc_append(proc);
    
    reflock_unlock(&(surface->reflock));
    
    return error;
#else /* HOST_ENV */
    return kSurfaceErrorUndefined;
#endif
}
