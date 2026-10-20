/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2025 - 2026 emexlab
 Copyright (C) 2026 ruri1208

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

#ifndef PEUSERSPACEMANAGER_H
#define PEUSERSPACEMANAGER_H

#import <Foundation/Foundation.h>

typedef enum: UInt8 {
    kPEUserspaceRebootTypeDefault,
    kPEUserspaceRebootTypeMinimal,  /* only containerd launches */
    kPEUserspaceRebootTypeEmpty,    /* without daemons, just ksurface */
} PEUserspaceRebootType;

typedef enum: UInt8 {
    kPEUserspaceModeDefault,
    kPEUserspaceModeMinimal,
    kPEUserspaceModeEmpty,
} PEUserspaceMode;

@interface PEUserspaceManager : NSObject

@property (atomic,readonly) BOOL isBooted;
@property (atomic,readonly) BOOL isLaunchServiceManagerStable;
@property (readonly) PEUserspaceMode mode;

+ (instancetype)shared;

- (void)bootWithKextLoadingEnabled:(BOOL)enabled;
- (BOOL)rebootUserspace;
- (BOOL)restore;
- (BOOL)restoreEverything;
- (BOOL)reloadDaemons;
- (BOOL)clearApplicationCaches;

@end

#endif /* PEUSERSPACEMANAGER_H */
