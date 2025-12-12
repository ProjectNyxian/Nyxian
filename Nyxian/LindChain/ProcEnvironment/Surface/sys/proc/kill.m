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

#import <LindChain/ProcEnvironment/Surface/sys/proc/kill.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/Surface/permit.h>
#import <LindChain/ProcEnvironment/Utils/klog.h>
#import <LindChain/Multitask/ProcessManager/LDEProcessManager.h>

DEFINE_SYSCALL_HANDLER(kill)
{
    /* getting args, nu checks needed the syscall server does them */
    pid_t pid = (pid_t)args[0];
    int signal = (int)args[1];
    
    /* checking signal bounds */
    if(signal <= 0 || signal >= NSIG)
    {
        sys_return_failure(EINVAL);
    }
    
    klog_log(@"syscall:kill", @"pid %d requested to signal pid %d with %d", proc_getpid(sys_proc_copy_), pid, signal);
    
    /*
     * checking if the caller process that makes the call is the same process,
     * also checks if the caller process has the entitlement to kill
     * and checks if the process has permitive over the other process.
     */
    if(pid != proc_getpid(sys_proc_copy_) &&
       (!entitlement_got_entitlement(proc_getentitlements(sys_proc_copy_), PEEntitlementProcessKill) ||
        !permitive_over_process_allowed(sys_proc_copy_, pid)))
    {
        klog_log(@"syscall:kill", @"pid %d not autorized to kill pid %d", proc_getpid(sys_proc_copy_), pid);
        sys_return_failure(EPERM);
    }

    /* getting the processes high level structure */
    LDEProcess *process = [[LDEProcessManager shared] processForProcessIdentifier:pid];
    if(!process)
    {
        /*
         * returns the same value as normal failure to prevent deterministic exploitation,
         * of process reference counting.
         */
        klog_log(@"syscall:kill", @"pid %d not found on high level process manager", pid);
        sys_return_failure(EPERM);
    }
    
    /* signaling the process */
    [process sendSignal:signal];
    klog_log(@"syscall:kill", @"pid %d signaled pid %d", proc_getpid(sys_proc_copy_), pid);
    
    sys_return;
}
