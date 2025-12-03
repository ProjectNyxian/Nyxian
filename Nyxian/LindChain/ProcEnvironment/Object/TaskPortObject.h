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

#ifndef PROCENVIRONMENT_TASKPORTOBJECT
#define PROCENVIRONMENT_TASKPORTOBJECT

/* ----------------------------------------------------------------------
 *  Apple API Headers
 * -------------------------------------------------------------------- */
#import <Foundation/Foundation.h>

/* ----------------------------------------------------------------------
 *  Environment API Headers
 * -------------------------------------------------------------------- */
#import <LindChain/ProcEnvironment/Object/MachPortObject.h>

API_AVAILABLE(ios(26.0));
@interface TaskPortObject : MachPortObject

// MARK: Apple seems to have implemented mach port transmission into iOS 26, as in iOS 18.7 RC and below it crashes but on iOS 26.0 RC it actually transmitts the task port
+ (instancetype)taskPortSelf;

- (pid_t)pid;

@end

#endif /* PROCENVIRONMENT_TASKPORTOBJECT */
