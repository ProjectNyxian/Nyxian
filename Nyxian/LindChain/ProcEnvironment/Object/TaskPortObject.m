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

#import <LindChain/ProcEnvironment/Object/TaskPortObject.h>

@implementation TaskPortObject

// MARK: Apple seems to have implemented mach port transmission into iOS 26, as in iOS 18.7 RC and below it crashes but on iOS 26.0 RC it actually transmitts the task port
+ (instancetype)taskPortSelf
{
    return [[TaskPortObject alloc] initWithPort:mach_task_self()];
}

- (pid_t)pid
{
    /* checking port */
    if(![self isUsable])
    {
        return -1;
    }
    
    /* asking mach kernel for pid of task_t */
    pid_t pid = -1;
    kern_return_t kr = pid_for_task([self port], &pid);
    if(kr != KERN_SUCCESS)
    {
        return -1;
    }
    
    /* returning pid */
    return pid;
}

@end
