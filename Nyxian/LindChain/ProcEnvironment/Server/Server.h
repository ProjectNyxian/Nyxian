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

#ifndef PROCENVIRONMENT_SERVER_SERVER_H
#define PROCENVIRONMENT_SERVER_SERVER_H

#import <Foundation/Foundation.h>

extern mach_port_t xpc_endpoint_copy_listener_port_4sim(NSObject<OS_xpc_object>*);
extern NSObject<OS_xpc_object> *xpc_endpoint_create_mach_port_4sim(mach_port_t port);

@interface NSXPCListenerEndpoint ()

@property(nonatomic, setter=_setEndpoint:) xpc_object_t _endpoint;

@end

@interface Server : NSObject <NSXPCListenerDelegate>

+ (NSXPCListenerEndpoint*)getTicket;
- (BOOL)endpointUnregisterAndValidate:(xpc_endpoint_t)endpoint;

@end

#endif /* PROCENVIRONMENT_SERVER_SERVER_H */
