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

#ifndef NXDOCUMENTMANAGER_H
#define NXDOCUMENTMANAGER_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <LindChain/IDEFoundation/NXDocument.h>

@interface NXDocumentManager : NSObject

- (instancetype)init;
+ (instancetype)shared;

- (void)open:(NSURL*)url completion:(void (^)(NXDocument*))completion;
- (void)close:(NSURL*)url completion:(void (^)(void))completion;
- (void)saveAllWithCompletion:(void (^)(void))completion;
- (void)changeAllLockStateToBoolean:(BOOL)isLocked;

@end

#endif /* NXDOCUMENTMANAGER_H */
