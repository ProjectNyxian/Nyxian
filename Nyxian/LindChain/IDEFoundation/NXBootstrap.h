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

#ifndef NXBOOTSTRAP_H
#define NXBOOTSTRAP_H

#import <Foundation/Foundation.h>

#define NXBOOTSTRAP_NEWEST_VERSION  29
#define NXBOOTSTRAP_CSTEP           (double)(1.0 / NXBOOTSTRAP_NEWEST_VERSION)

@interface NXBootstrap : NSObject

@property (nonatomic, readonly, strong, nonnull) NSURL *rootURL;
@property (nonatomic, readonly, strong, nonnull) NSURL *sdkURL;
@property (nonatomic, readonly, strong, nonnull) NSURL *includeURL;
@property (nonatomic, readonly, strong, nonnull) NSURL *projectsURL;
@property (nonatomic, readonly, strong, nonnull) NSURL *cacheURL;
@property (nonatomic, readonly, strong, nonnull) NSURL *bootstrapPlistURL;
@property (nonatomic, readonly, strong, nonnull) NSURL *swiftURL;
@property (nonatomic, readonly, strong, nonnull) NSURL *swiftModuleCacheURL;
@property (nonatomic, readonly, strong, nonnull) NSURL *rootfsURL;

@property (atomic, readonly) UInt64 version;
@property (atomic, readonly) BOOL isInstalled;

- (instancetype _Nonnull)init;
+ (instancetype _Nonnull)shared;

- (void)bootstrap;

- (NSString  * _Nullable)relativeToBootstrapWithAbsolutePath:( NSString  * _Nonnull)path;
- (void)clearURL:(NSURL * _Nonnull)url;

- (void)waitTillDone;
- (void)waitTillDoneNoButton;
- (BOOL)isNewest;

@end

#endif /* NXBOOTSTRAP_H */
