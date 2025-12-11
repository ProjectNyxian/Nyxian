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

#import <LindChain/ProcEnvironment/Surface/sys/compat/bamset.h>
#import <LindChain/Multitask/ProcessManager/LDEProcessManager.h>
#import <LindChain/ProcEnvironment/Utils/klog.h>

DEFINE_SYSCALL_HANDLER(bamset)
{
    /* null pointer check */
    if(args == NULL)
    {
        return -1;
    }
    
    /* getting boolean */
    bool active = args[0];
    
    /* getting process */
    LDEProcess *process = [[LDEProcessManager shared] processForProcessIdentifier:proc_getpid(sys_proc_copy_)];
    if(process)
    {
        klog_log(@"syscall:bamset", @"pid %d set background audio mode: %d", proc_getpid(sys_proc_copy_), active);
        process.audioBackgroundModeUsage = active;
    }
#if KLOG_ENABLED
    else
    {
        klog_log(@"syscall:bamset", @"failed to find process", proc_getpid(sys_proc_copy_));
    }
#endif /* KLOG_ENABLED */
    
    return 0;
}
