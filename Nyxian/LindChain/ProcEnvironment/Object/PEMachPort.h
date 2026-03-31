/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 cr4zyengineer

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#ifndef PEMACHPORT_H
#define PEMACHPORT_H

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

@interface PEMachPort : PEObject <NSCopying>

@property (nonatomic, readonly) mach_port_t port;
@property (nonatomic, readonly, getter=isUsable) BOOL usable;
@property (nonatomic, readonly, getter=getIPCType) ipc_info_object_type_t ipc_type;
@property (nonatomic, readonly, getter=getRefCnt) mach_port_urefs_t ref;

+ (instancetype)portWithPortName:(mach_port_name_t)port;
- (instancetype)initWithPortName:(mach_port_name_t)port;

@end

#endif /* PEMACHPORT_H */
