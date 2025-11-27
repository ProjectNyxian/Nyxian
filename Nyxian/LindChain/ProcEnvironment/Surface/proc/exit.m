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

#import <LindChain/ProcEnvironment/Surface/proc/exit.h>
#import <LindChain/ProcEnvironment/Surface/proc/fetch.h>
#import <LindChain/ProcEnvironment/Surface/proc/replace.h>
#import <LindChain/ProcEnvironment/Surface/proc/remove.h>
#import <LindChain/ProcEnvironment/Surface/proc/def.h>

#ifdef HOST_ENV
#import <LindChain/Multitask/ProcessManager/LDEProcessManager.h>
#import <LindChain/ProcEnvironment/Utils/klog.h>
#endif

ksurface_error_t proc_exit_for_pid(pid_t pid)
{
#ifdef HOST_ENV
    reflock_lock(&(surface->reflock));
    
    klog_log(@"proc:exit", @"pid %d requested to exit", pid);
    
    // Get process ptr
    unsigned int index = 0;
    ksurface_proc_t *proc = NULL;
    ksurface_error_t error = proc_ptr_for_pid(pid, &proc, &index);
    if(error != kSurfaceErrorSuccess)
    {
        klog_log(@"proc:exit", @"pid %d wasnt found", pid);
        reflock_unlock(&(surface->reflock));
        return error;
    }
    
    // Prepare
    pid_t flagged_pid[PROC_MAX] = { pid };
    int flagged_pid_cnt = 1;
    
    // Iterating through all process structures
    for(uint32_t i = index; i < surface->proc_info.proc_count; i++)
    {
        // Copying it to the process ptr passed
        for(int i = 0; i < flagged_pid_cnt; i++)
        {
            if(flagged_pid[i] == proc_getppid(surface->proc_info.proc[i]))
            {
                klog_log(@"proc:exit", @"flagging pid %d", proc_getpid(surface->proc_info.proc[i]));
                flagged_pid[flagged_pid_cnt++] = proc_getpid(surface->proc_info.proc[i]);
                break;
            }
        }
    }
    
    // Now we shall have all suspicious pids
    // Now second pass
    for(int i = 0; i < flagged_pid_cnt; i++)
    {
        error = proc_remove_by_pid(flagged_pid[i]);
        if(error != kSurfaceErrorSuccess)
        {
            klog_log(@"proc:exit", @"failed to remove process structure for pid %d", flagged_pid[i]);
            reflock_unlock(&(surface->reflock));
            return error;
        }
        else
        {
            klog_log(@"proc:exit", @"removed process structure for pid %d", flagged_pid[i]);
        }
    }
    
    reflock_unlock(&(surface->reflock));
    
    // 3rd pass
    for(int i = 1; i < flagged_pid_cnt; i++)
    {
        LDEProcess *process = [LDEProcessManager shared].processes[@(flagged_pid[i])];
        if(process != nil)
        {
            klog_log(@"proc:exit", @"terminating process for pid %d", flagged_pid[i]);
            [process terminate];
        }
        else
        {
            klog_log(@"proc:exit", @"failed to terminate process for pid %d", flagged_pid[i]);
        }
    }
    
    return error;
#else
    return kSurfaceErrorUndefined;
#endif /* HOST_ENV */
}
