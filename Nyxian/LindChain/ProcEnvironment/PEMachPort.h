/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2025 - 2026 emexlab

 This file is part of Nyxian.

 Licensed under the emexLabs Public Source License, version 1.1
 (EPSL 1.1).

 Private use and modification are permitted under the license.
 Redistribution of source or binaries, modified or unmodified,
 requires prior written permission from emexLabs.

 External deployment is subject to the source-availability
 requirements and other conditions of the license.

 Provided "AS IS", without warranty, to the extent permitted by law.

 See LICENSE for the full license terms.
*/

#ifndef PEMACHPORT_H
#define PEMACHPORT_H

/* ----------------------------------------------------------------------
 *  Apple API Headers
 * -------------------------------------------------------------------- */
#import <Foundation/Foundation.h>
#import <mach/mach.h>


/* ----------------------------------------------------------------------
 *  Class Declarations
 * -------------------------------------------------------------------- */

@interface PEMachPort : NSObject <NSSecureCoding,NSCopying>

@property (nonatomic, readonly) mach_port_t port;
@property (nonatomic, readwrite) BOOL sendOnce;
@property (nonatomic, readonly, getter=isUsable) BOOL usable;
@property (nonatomic, readonly, getter=getIPCType) ipc_info_object_type_t ipc_type;
@property (nonatomic, readonly, getter=getRefCnt) mach_port_urefs_t ref;

+ (instancetype)portWithPortName:(mach_port_name_t)port;
- (instancetype)initWithPortName:(mach_port_name_t)port;

@end

#endif /* PEMACHPORT_H */
