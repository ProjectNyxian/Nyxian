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

#ifndef NXPROJECT_H
#define NXPROJECT_H

#import <Foundation/Foundation.h>
#import <LindChain/IDEFoundation/NXPlist.h>
#import <LindChain/IDEFoundation/NXType.h>
#import <LindChain/ProcEnvironment/Surface/trust/entitlement.h>

@interface NXProjectConfig : NXPlist

@property (nonatomic,readonly) NXProjectFormatKind formatKind;
@property (nonatomic,readonly) NXProjectSchemeKind schemeKind;
@property (nonatomic,strong,readonly) NSString *executable;
@property (nonatomic,strong,readonly) NSString *displayName;
@property (nonatomic,strong,readonly) NSString *organizationPrefix;
@property (nonatomic,strong,readonly) NSString *bundleid;
@property (nonatomic,strong,readonly) NSDictionary *infoDictionary;
@property (nonatomic,strong,readonly) NSArray<NSString*> *compilerFlags;
@property (nonatomic,strong,readonly) NSArray<NSString*> *linkerFlags;
@property (nonatomic,strong,readonly) NSArray<NSString*> *swiftFlags;
@property (nonatomic,strong,readonly) NSString *deploymentTarget;
@property (nonatomic,strong,readonly) NSString *outputPath;
@property (nonatomic,readonly) BOOL signMachOWithNyxianEntitlements;
@property (nonatomic,readonly) BOOL linkFrameworksAutomatically;

@property (nonatomic,readonly) BOOL deploymentTargetContainsWhitespaces;

+ (NSArray<NSString*>*)sdkCompilerFlags;

@end

@interface NXEntitlementsConfig : NXPlist
@end

@interface NXProject : NSObject

@property (nonatomic,strong,readonly) NXProjectConfig *projectConfig;
@property (nonatomic,strong,readonly) NXEntitlementsConfig *entitlementsConfig;

@property (nonatomic,strong,readonly) NSURL *url;
@property (nonatomic,strong,readonly) NSURL *cacheURL;
@property (nonatomic,strong,readonly) NSURL *resourcesURL;
@property (nonatomic,strong,readonly) NSURL *payloadURL;
@property (nonatomic,strong,readonly) NSURL *bundleURL;
@property (nonatomic,strong,readonly) NSURL *machoURL;
@property (nonatomic,strong,readonly) NSURL *packageURL;

- (instancetype)initWithURL:(NSURL*)url;
+ (instancetype)projectWithURL:(NSURL*)url;

+ (instancetype)createProjectAtURL:(NSURL*)url withName:(NSString*)name withOrganizationIdentifier:(NSString*)organizationIdentifier withBundleIdentifier:(NSString*)bundleid withSchemeKind:(NXProjectSchemeKind)schemeKind withLanguageKind:(NXProjectLanguageKind)languageKind withInterfaceKind:(NXProjectInterfaceKind)interfaceKind;
+ (NSMutableDictionary<NSString*,NSMutableArray<NXProject*>*>*)listProjectsAtURL:(NSURL*)url;

- (BOOL)syncFolderStructureToCache;

- (void)removeProject;
- (BOOL)reload;

@end

#endif /* NXPROJECT_H */
