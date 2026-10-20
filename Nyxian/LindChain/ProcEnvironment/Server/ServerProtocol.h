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

#ifndef PROCENVIRONMENT_SERVER_SERVERPROTOCOL_H
#define PROCENVIRONMENT_SERVER_SERVERPROTOCOL_H

#import <Foundation/Foundation.h>
#import <LindChain/Private/UIKitPrivate.h>
#import <LindChain/ProcEnvironment/PEProcessManager.h>
#import <LindChain/ProcEnvironment/PEMachPort.h>
#import <LindChain/ProcEnvironment/Shims/posix_spawn.h>
#import <LindChain/ProcEnvironment/Surface/surface.h>

@protocol ServerProtocol

/*
 posix_spawn
 */
- (void)spawnProcessWithPath:(NSString*)path withArguments:(NSArray<NSObject<NSSecureCoding,NSCopying>*>*)arguments withEnvironmentVariables:(NSDictionary *)environment withFileTable:(PEFileTable*)fileTable withWorkingDirectory:(NSString*)workingDirectory withSpawnFlags:(short)spawnFlags withSpawnPgroup:(pid_t)spawnPgroup withReply:(void (^)(int64_t))reply;

/*
 App Switcher Services
 */
- (void)setSnapshot:(UIImage*)image;

@end

#endif /* PROCENVIRONMENT_SERVER_SERVERPROTOCOL_H */
