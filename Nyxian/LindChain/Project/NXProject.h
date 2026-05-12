/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 mach-port-t

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
#import <LindChain/Project/NXTarget.h>
#import <LindChain/ProcEnvironment/Surface/entitlement.h>

@interface NXProjectConfig : NXPlist

@property (nonatomic,readonly) NXProjectFormatKind formatKind;
@property (nonatomic,readonly) NXProjectSchemeKind schemeKind;
@property (nonatomic,strong,readonly) NSString *organizationIdentifier;
@property (nonatomic,strong,readonly) NSString *displayName;
@property (nonatomic,strong,readonly) NSString *bundleIdentifier;

@property (nonatomic,strong,readonly) NSArray<NXTarget*> *targets;

@end

@interface NXEntitlementsConfig : NXPlist

@property (nonatomic,readonly) PEEntitlement entitlement;

@end

@interface NXProject : NSObject

@property (nonatomic,strong,readonly) NXProjectConfig *projectConfig;
@property (nonatomic,strong,readonly) NXEntitlementsConfig *entitlementsConfig;

@property (nonatomic,strong,readonly) NSURL *url;
@property (nonatomic,strong,readonly) NSURL *cacheURL;

- (instancetype)initWithURL:(NSURL*)url;
+ (instancetype)projectWithURL:(NSURL*)url;

+ (instancetype)createProjectAtURL:(NSURL*)url withName:(NSString*)name withOrganizationIdentifier:(NSString*)organizationIdentifier withBundleIdentifier:(NSString*)bundleid withSchemeKind:(NXProjectSchemeKind)schemeKind withLanguageKind:(NXProjectLanguageKind)languageKind withInterfaceKind:(NXProjectInterfaceKind)interfaceKind;
+ (NSMutableDictionary<NSString*,NSMutableArray<NXProject*>*>*)listProjectsAtURL:(NSURL*)url;

- (BOOL)syncFolderStructureToCache;

- (void)removeProject;
- (BOOL)reload;

@end

#endif /* NXPROJECT_H */
