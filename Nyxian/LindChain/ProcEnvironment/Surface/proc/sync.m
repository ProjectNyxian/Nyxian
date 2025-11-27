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

#import <LindChain/ProcEnvironment/Surface/proc/sync.h>
#import <LindChain/ProcEnvironment/Surface/proc/def.h>
#import <LindChain/ProcEnvironment/Surface/proc/remove.h>

#ifdef HOST_ENV
#import <LindChain/Multitask/ProcessManager/LDEProcessManager.h>
#endif

// I dont know why this works, but dont break it

ksurface_error_t proc_sync(void)
{
#ifdef HOST_ENV
    reflock_lock(&(surface->reflock));
    
    NSDictionary<NSNumber*,LDEProcess*> *processCopy = [LDEProcessManager shared].processes;
    
    pid_t flagged_pid[PROC_MAX] = {};
    int flagged_pid_cnt = 0;
    
    for(uint32_t i = 1; i < surface->proc_info.proc_count; i++)
    {
        // Checking if its the process structure were looking for
        pid_t pid = proc_getpid(surface->proc_info.proc[i]);
        LDEProcess *process = [processCopy objectForKey:@(pid)];
        if(process == nil || ![process.processHandle isValid])
        {
            flagged_pid[flagged_pid_cnt++] = pid;
        }
    }
    
    for(int i = 0; i < flagged_pid_cnt; i++)
    {
        ksurface_error_t error = proc_remove_by_pid(flagged_pid[i]);
        if(error != kSurfaceErrorSuccess)
        {
            reflock_unlock(&(surface->reflock));
            return error;
        }
    }
    
    reflock_unlock(&(surface->reflock));
    
    return kSurfaceErrorSuccess;
#else
    return kSurfaceErrorUndefined;
#endif
}
