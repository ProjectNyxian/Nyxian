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
#endif

ksurface_error_t proc_exit_for_pid(pid_t pid)
{
#ifdef HOST_ENV
    reflock_lock(&(surface->reflock));
    
    ksurface_proc_t proc = {};
    ksurface_error_t error = proc_for_pid(pid, &proc);
    if(error != kSurfaceErrorSuccess)
    {
        reflock_unlock(&(surface->reflock));
        return error;
    }
    
    // Prepare
    pid_t flagged_pid[PROC_MAX] = { pid };
    int flagged_pid_cnt = 1;
    
    // Iterating through all process structures
    for(uint32_t i = 0; i < surface->proc_info.proc_count; i++)
    {
        // Copying it to the process ptr passed
        proc = surface->proc_info.proc[i];
        
        for(int i = 0; i < flagged_pid_cnt; i++)
        {
            if(flagged_pid[i] == proc_getppid(proc))
            {
                flagged_pid[flagged_pid_cnt++] = proc_getpid(proc);
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
            reflock_unlock(&(surface->reflock));
            return error;
        }
    }
    
    reflock_unlock(&(surface->reflock));
    
    // 3rd pass
    for(int i = 1; i < flagged_pid_cnt; i++)
    {
        LDEProcess *process = [LDEProcessManager shared].processes[@(flagged_pid[i])];
        if(process != nil)
        {
            [process terminate];
        }
    }
    
    return error;
#else
    return kSurfaceErrorUndefined;
#endif /* HOST_ENV */
}
