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

DEFINE_SYSCALL_HANDLER(bamset)
{
    /* syscall wrapper */
    sys_name("SYS_bamset");
    
    /* getting boolean */
    bool active = args[0];
    
    /* getting process */
    LDEProcess *process = [[LDEProcessManager shared] processForProcessIdentifier:proc_getpid(sys_proc_copy_)];
    if(process)
    {
        process.audioBackgroundModeUsage = active;
    }
    
    sys_return;
}
