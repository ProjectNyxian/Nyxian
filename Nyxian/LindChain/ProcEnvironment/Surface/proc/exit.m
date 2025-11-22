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
#import <LindChain/ProcEnvironment/Surface/proc/helper.h>

#ifdef HOST_ENV
#import <LindChain/Multitask/LDEProcessManager.h>
#endif

ksurface_error_t proc_exit_for_pid(pid_t pid)
{
#ifdef HOST_ENV
    proc_helper_lock(true);
    
    ksurface_proc_t proc = {};
    ksurface_error_t error = proc_for_pid_nolock(pid, &proc);
    if(error != kSurfaceErrorSuccess)
    {
        proc_helper_unlock(true);
        return error;
    }
    
    // Flagging the process, no process can now spawn that is part of the same tree
    proc.bsd.kp_proc.p_flag = proc.bsd.kp_proc.p_flag | P_WEXIT;
    proc_replace_nolock(proc);
    
    // Prepare
    pid_t flagged_pid[PROC_MAX] = { pid };
    int flagged_pid_cnt = 1;
    
    // Loop
    for(;error == kSurfaceErrorSuccess; pid++)
    {
        error = proc_for_pid_nolock(pid, &proc);
        for(int i = 0; i < flagged_pid_cnt; i++)
        {
            if(flagged_pid[i] == proc_getppid(proc))
            {
                flagged_pid[flagged_pid_cnt++] = pid;
                
                proc.bsd.kp_proc.p_flag = proc.bsd.kp_proc.p_flag | P_WEXIT;
                proc_replace_nolock(proc);
            }
        }
    }
    
    // Now we shall have all suspicious pids
    // Now second pass
    for(int i = 0; i < flagged_pid_cnt; i++)
    {
        error = proc_remove_by_pid_nolock(flagged_pid[i]);
    }
    
    proc_helper_unlock(true);
    
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
