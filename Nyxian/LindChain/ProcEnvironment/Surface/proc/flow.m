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

#import <LindChain/ProcEnvironment/Surface/proc/def.h>
#import <LindChain/ProcEnvironment/Surface/proc/flow.h>
#import <LindChain/Multitask/ProcessManager/LDEProcessManager.h>

ksurface_error_t proc_suspend(ksurface_proc_t *proc)
{
    if(proc == NULL) return kSurfaceErrorNullPtr;
    LDEProcess *process = [LDEProcessManager shared].processes[@(proc_getpid(proc))];
    if(process == NULL)
    {
        return kSurfaceErrorNullPtr;
    }
    [process suspend];
    return kSurfaceErrorSuccess;
}

ksurface_error_t proc_resume(ksurface_proc_t *proc)
{
    if(proc == NULL) return kSurfaceErrorNullPtr;
    LDEProcess *process = [LDEProcessManager shared].processes[@(proc_getpid(proc))];
    if(process == NULL)
    {
        return kSurfaceErrorNullPtr;
    }
    [process resume];
    return kSurfaceErrorSuccess;
}
