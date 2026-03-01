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

#ifndef PROCENVIRONMENT_MACHPORTOBJECT
#define PROCENVIRONMENT_MACHPORTOBJECT

/* ----------------------------------------------------------------------
 *  Apple API Headers
 * -------------------------------------------------------------------- */
#import <Foundation/Foundation.h>
#import <mach/mach.h>

/* ----------------------------------------------------------------------
 *  Environment API Headers
 * -------------------------------------------------------------------- */
#import <LindChain/ProcEnvironment/Object/PEObject.h>

/* ----------------------------------------------------------------------
 *  Class Declarations
 * -------------------------------------------------------------------- */

@interface MachPortObject : PEObject <NSSecureCoding>

@property (nonatomic, readonly) mach_port_t port;

- (instancetype)initWithPort:(mach_port_t)port;

- (BOOL)isUsable;

@end

#endif /* PROCENVIRONMENT_MACHPORTOBJECT */
