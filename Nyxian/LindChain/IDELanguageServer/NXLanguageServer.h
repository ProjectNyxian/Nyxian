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

#ifndef NXLANGUAGESERVER_H
#define NXLANGUAGESERVER_H

#import <Foundation/Foundation.h>
#import <MobileDevelopmentKit/MDKDiagnostic.h>
#import <MobileDevelopmentKit/MDKFileSourceLocation.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>

@interface NXLanguageServer : NSObject

- (instancetype)init:(NSString*)filepath;

- (void)reparseFile:(NSString*)content withArgs:(NSArray*)args;

- (NSArray<MDKDiagnostic *> *)getDiagnostics;
- (MDKFileSourceLocation*)getDefinitionAtLocation:(MDKSourceLocation)location;

- (void)releaseMemory;

@end

#endif /* NXLANGUAGESERVER_H */
