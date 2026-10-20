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

#ifndef PELAUNCHSERVICE_H
#define PELAUNCHSERVICE_H

#import <Foundation/Foundation.h>
#import <LindChain/ProcEnvironment/PEProcess.h>
#import <LindChain/ProcEnvironment/PELaunchServiceInstance.h>

@interface PELaunchService : NSObject <PELaunchServiceInstanceDelegate>

@property (atomic,readonly,copy) NSMutableArray<PELaunchServiceInstance*> *instances;
@property (nonatomic,readonly) NSString *executablePath;
@property (nonatomic,readonly) NSString *serviceIdentifier;
@property (nonatomic,readonly) BOOL autoRestart;
@property (nonatomic,readonly) BOOL enabled;
@property (nonatomic,readonly) BOOL isMultiInstanceDaemon;

+ (instancetype)launchServiceWithPlistPath:(NSString*)plistPath;
- (instancetype)initWithPlistPath:(NSString*)plistPath;
- (BOOL)isServiceWithServiceIdentifier:(NSString*)serviceIdentifier;

- (PELaunchServiceInstance*)newInstance;

@end

#endif /* PELAUNCHSERVICE_H */
