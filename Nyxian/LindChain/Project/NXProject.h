/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 cr4zyengineer

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#ifndef NXPROJECT_H
#define NXPROJECT_H

#import <Foundation/Foundation.h>
#import <LindChain/Project/NXPlist.h>
#import <LindChain/Project/NXType.h>
#import <LindChain/ProcEnvironment/Surface/entitlement.h>

@interface NXProjectConfig : NXPlist

@property (nonatomic,readonly) NXProjectFormat projectFormat;
@property (nonatomic,readonly) NXProjectType type;
@property (nonatomic,strong,readonly) NSString *executable;
@property (nonatomic,strong,readonly) NSString *displayName;
@property (nonatomic,strong,readonly) NSString *bundleid;
@property (nonatomic,strong,readonly) NSString *version;
@property (nonatomic,strong,readonly) NSString *shortVersion;
@property (nonatomic,strong,readonly) NSDictionary *infoDictionary;
@property (nonatomic,strong,readonly) NSArray<NSString*> *compilerFlags;
@property (nonatomic,strong,readonly) NSArray<NSString*> *linkerFlags;
@property (nonatomic,strong,readonly) NSString *deploymentTarget;
@property (nonatomic,strong,readonly) NSString *outputPath;
@property (nonatomic,readonly) BOOL signMachOWithNyxianEntitlements;

+ (NSArray<NSString*>*)sdkCompilerFlags;

@end

@interface NXEntitlementsConfig : NXPlist

@property (nonatomic,readonly) PEEntitlement entitlement;

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
@property (nonatomic,strong,readonly) NSString *uuid;

- (instancetype)initWithPath:(NSString*)path;

+ (instancetype)projectWithPath:(NSString*)path;
+ (instancetype)createProjectAtPath:(NSString*)path withName:(NSString*)name withBundleIdentifier:(NSString*)bundleid withType:(NXProjectType)type withLanguage:(NXCodeTemplateLanguage)language;
+ (NSMutableDictionary<NSString*,NSMutableArray<NXProject*>*>*)listProjectsAtPath:(NSString*)path;

- (void)removeProject;
- (BOOL)reload;

@end

#endif /* NXPROJECT_H */
