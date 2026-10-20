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

#ifndef NXPHASEENGINE_H
#define NXPHASEENGINE_H

#import <MobileDevelopmentKit/MobileDevelopmentKit.h>
#import <LindChain/IDEFoundation/NXProject.h>

@interface NXPhaseEngine : MDKPhaseEngine

+ (instancetype _Nullable)engineWithProject:(NXProject * _Nonnull)project
                                      error:(NSError * _Nullable * _Nonnull)error;

@end

#endif /* NXPHASEENGINE_H */
