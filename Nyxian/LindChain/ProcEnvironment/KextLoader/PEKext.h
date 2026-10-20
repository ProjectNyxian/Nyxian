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

#ifndef PEKEXT_H
#define PEKEXT_H

#import <Foundation/Foundation.h>
#import <LindChain/ProcEnvironment/KextLoader/PEDependency.h>

@interface PEKext : NSObject

@property (nonatomic,copy) NSString *executablePath;
@property (nonatomic,copy) NSString *bundlePath;
@property (nonatomic,copy) NSString *bundleID;
@property (nonatomic,copy) NSString *version;
@property (nonatomic,strong) NSArray<PEDependency*> *dependencies;
@property (nonatomic) uint64_t flags;
@property (nonatomic) uint32_t abi_version;
@property (atomic) BOOL isEnabled;

- (int)load;

- (instancetype)initWithPath:(NSString*)path;

+ (instancetype)appleIOSKext;
+ (instancetype)ksurfaceMainKext;

@end

#endif /* PEKEXT_H */
