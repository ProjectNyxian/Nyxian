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

#ifndef NXREMOTECOMPILER_H
#define NXREMOTECOMPILER_H

#import <Foundation/Foundation.h>
#import <MobileDevelopmentKit/MobileDevelopmentKit.h>

@protocol NXCompilationServiceProtocol <NSObject>

- (void)executeJob:(MDKJob*)job withReply:(void (^)(BOOL success, NSArray<MDKDiagnostic*> *diagnostics, NSString *mainSource))reply;
- (void)setupDependencyScannerWithArguments:(NSArray<NSString*>*)arguments withReply:(void (^)(BOOL success))reply;
- (void)headersForFile:(MDKFile*)file withReply:(void (^)(NSArray<MDKFile*> *files))reply;
- (void)dependenciesForFile:(MDKFile*)file withReply:(void (^)(BOOL success, NSArray<MDKFile*> *files, NSArray<MDKDependency*> *dependencies))reply;

@end

@class NXRemoteCompiler;

@interface NXRemoteDependencyScanner : NSObject

+ (instancetype)dependencyScannerWithRemoteCompiler:(NXRemoteCompiler*)compiler;

- (NSArray<MDKFile*>*)headerFilesForFile:(MDKFile*)file;
- (BOOL)dependenciesForFile:(MDKFile*)file withHeaderFilePaths:(NSArray<MDKFile*>**)headerFilePaths withDependencies:(NSArray<MDKDependency*>**)dependencies;

@end

@interface NXRemoteCompiler : NSObject

+ (BOOL)isAvailable;
+ (instancetype)newRemoteCompiler;

- (BOOL)executeJob:(MDKJob*)job withDiagnostics:(NSArray<MDKDiagnostic*>**)diagnostics withMainSource:(NSString**)mainSource;
- (BOOL)setupDependencyScannerWithArguments:(NSArray<NSString*>*)arguments;
- (NSArray<MDKFile*>*)headersForFile:(MDKFile*)file;
- (BOOL)dependenciesForFile:(MDKFile*)file withHeaderFilePaths:(NSArray<MDKFile*>**)headerFilePaths withDependencies:(NSArray<MDKDependency*>**)dependencies;
- (MDKDependencyScanner*)dependencyScanner;

@end

#endif /* NXREMOTECOMPILER_H */
