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

#import <LindChain/Project/NXProject.h>
#import <LindChain/Utils/LDEThreadController.h>
#import <LindChain/Project/NXCodeTemplate.h>
#import <LindChain/Project/NXUser.h>
#import <Nyxian-Swift.h>

@implementation NXProjectConfig

+ (NSArray*)sdkCompilerFlags
{
    return @[
        @"-target",
        @"apple-arm64-ios26.4",
        @"-isysroot",
        [[Bootstrap shared] sdkPath],
        @"-resource-dir",
        [[Bootstrap shared] bootstrapPath:@"/Include"]
    ];
}

- (BOOL)reloadIfNeeded
{
    BOOL reloaded = [super reloadIfNeeded];
    if(reloaded)
    {
        /* MARK: projectFormat */
        NSString *projectFormat = [self readSecureFromKey:@"NXProjectFormat" withDefaultValue:@"NXKate"];
        
        if([projectFormat isEqualToString:@"NXKate"])
        {
            /*
             * TODO: add deprecation message to project issue navigator
             * this wont exist for ever, i plan on removing compat
             * for older project types after each 5th newest project
             * format, meaning NXKate will be removed
             * after 4 new project formats being released.
             * there can also be formats like NXProjectFormatFalconR1
             * the R would stand for revision, but revisions will be
             * safe from this rule... only major project formats..
             * so for NXProjectFormatFalconR1 to be removed for example
             * NXProjectFormatFalcon needs to be removed, revisions
             * compatibility will die together with the original.
             */
            _projectFormat = NXProjectFormatKate;
        }
        else if([projectFormat isEqualToString:@"NXFalcon"])
        {
            _projectFormat = NXProjectFormatFalcon;
        }
        else
        {
            _projectFormat = NXProjectFormatDefault;
        }
        
        /* MARK: keys */
        _executable = [self readSecureFromKey:@"LDEExecutable" withDefaultValue:@"Unknown"];
        _displayName = [self readSecureFromKey:@"LDEDisplayName" withDefaultValue:[self executable]];
        _bundleid = [self readSecureFromKey:@"LDEBundleIdentifier" withDefaultValue:[NSString stringWithFormat:@"app.nyxian.%@.%@", [[NXUser shared] username], [self executable]]];
        _version = [self readSecureFromKey:@"LDEBundleVersion" withDefaultValue:@"1.0"];
        _shortVersion = [self readSecureFromKey:@"LDEBundleShortVersion" withDefaultValue:[self version]];
        _infoDictionary = [self readSecureFromKey:@"LDEBundleInfo" withDefaultValue:@{}];
        _platformMinimumVersion = [self readSecureFromKey:@"LDEMinimumVersion" withDefaultValue:@"17.0"];
        _type = (int)[self readIntegerForKey:@"LDEProjectType" withDefaultValue:NXProjectTypeApp];
        _outputPath = [self readKey:@"LDEOutputPath"];
        
        /* MARK: compiler flags */
        NSArray *compilerFlags = [self readSecureFromKey:@"LDECompilerFlags" withDefaultValue:@[]];
        
        if([self projectFormat] == NXProjectFormatFalcon)
        {
            _compilerFlags = compilerFlags;
        }
        else if([self projectFormat] == NXProjectFormatKate)
        {
            NSMutableArray *array = [compilerFlags mutableCopy];
            
            [array addObjectsFromArray:@[
                @"-target",
                [self readSecureFromKey:@"LDEOverwriteTriple" withDefaultValue:[NSString stringWithFormat:@"apple-arm64-ios%@", [self platformMinimumVersion]]],
                @"-isysroot",
                [[Bootstrap shared] sdkPath],
                @"-resource-dir",
                [[Bootstrap shared] bootstrapPath:@"/Include"]
            ]];
            
            _compilerFlags = array;
        }
        else
        {
            _compilerFlags = @[];
        }
        
        /* MARK: linker flags */
        NSArray *linkerFlags = [self readSecureFromKey:@"LDELinkerFlags" withDefaultValue:@[]];
        
        if([self projectFormat] == NXProjectFormatFalcon)
        {
            _linkerFlags = linkerFlags;
        }
        else if([self projectFormat] == NXProjectFormatKate)
        {
            NSMutableArray *array = [linkerFlags mutableCopy];
            
            [array addObjectsFromArray:@[
                @"-platform_version",
                @"ios",
                [self platformMinimumVersion],
                [self readSecureFromKey:@"LDEVersion" withDefaultValue:@"26.4"],
                @"-arch",
                @"arm64",
                @"-syslibroot",
                [[Bootstrap shared] sdkPath],
                [@"-L" stringByAppendingString:[[Bootstrap shared] bootstrapPath:@"/lib"]]
            ]];
            
            _linkerFlags = array;
        }
        else
        {
            _linkerFlags = @[];
        }
    }
    return reloaded;
}

@end

@implementation NXEntitlementsConfig

- (BOOL)reloadIfNeeded
{
    BOOL reloaded = [super reloadIfNeeded];
    if(reloaded)
    {
        _entitlement = PEEntitlementNone;
        if([self readBooleanForKey:@"com.nyxian.pe.get_task_allowed" withDefaultValue:YES]) _entitlement |= PEEntitlementGetTaskAllowed;
        if([self readBooleanForKey:@"com.nyxian.pe.task_for_pid" withDefaultValue:NO]) _entitlement |= PEEntitlementTaskForPid;
        if([self readBooleanForKey:@"com.nyxian.pe.process_enumeration" withDefaultValue:NO]) _entitlement |= PEEntitlementProcessEnumeration;
        if([self readBooleanForKey:@"com.nyxian.pe.process_kill" withDefaultValue:NO]) _entitlement |= PEEntitlementProcessKill;
        if([self readBooleanForKey:@"com.nyxian.pe.process_spawn" withDefaultValue:NO]) _entitlement |= PEEntitlementProcessSpawn;
        if([self readBooleanForKey:@"com.nyxian.pe.process_spawn_signed_only" withDefaultValue:NO]) _entitlement |= PEEntitlementProcessSpawnSignedOnly;
        if([self readBooleanForKey:@"com.nyxian.pe.process_elevate" withDefaultValue:NO]) _entitlement |= PEEntitlementProcessElevate;
        if([self readBooleanForKey:@"com.nyxian.pe.host_manager" withDefaultValue:NO]) _entitlement |= PEEntitlementHostManager;
        if([self readBooleanForKey:@"com.nyxian.pe.credentials_manager" withDefaultValue:NO]) _entitlement |= PEEntitlementCredentialsManager;
        if([self readBooleanForKey:@"com.nyxian.pe.launch_services_start" withDefaultValue:NO]) _entitlement |= PEEntitlementLaunchServicesStart;
        if([self readBooleanForKey:@"com.nyxian.pe.launch_services_stop" withDefaultValue:NO]) _entitlement |= PEEntitlementLaunchServicesStop;
        if([self readBooleanForKey:@"com.nyxian.pe.launch_services_toggle" withDefaultValue:NO]) _entitlement |= PEEntitlementLaunchServicesToggle;
        if([self readBooleanForKey:@"com.nyxian.pe.launch_services_get_endpoint" withDefaultValue:NO]) _entitlement |= PEEntitlementLaunchServicesGetEndpoint;
        if([self readBooleanForKey:@"com.nyxian.pe.launch_services_set_endpoint" withDefaultValue:NO]) _entitlement |= PEEntitlementLaunchServicesSetEndpoint;
        if([self readBooleanForKey:@"com.nyxian.pe.launch_services_manager" withDefaultValue:NO]) _entitlement |= PEEntitlementLaunchServicesManager;
        if([self readBooleanForKey:@"com.nyxian.pe.dyld_hide_liveprocess" withDefaultValue:NO]) _entitlement |= PEEntitlementDyldHideLiveProcess;
        if([self readBooleanForKey:@"com.nyxian.pe.process_spawn_inherite_entitlements" withDefaultValue:NO]) _entitlement |= PEEntitlementProcessSpawnInheriteEntitlements;
        if([self readBooleanForKey:@"com.nyxian.pe.platform" withDefaultValue:NO]) _entitlement |= PEEntitlementPlatform;
        if([self readBooleanForKey:@"com.nyxian.pe.platform_root" withDefaultValue:NO]) _entitlement |= PEEntitlementPlatformRoot;
    }
    return reloaded;
}

@end

@implementation NXProject

- (instancetype)initWithPath:(NSString*)path
{
    self = [super init];
    _path = path;
    _cachePath = [[Bootstrap shared] bootstrapPath:[NSString stringWithFormat:@"/Cache/%@", [self uuid]]];
    _projectConfig = [[NXProjectConfig alloc] initWithPlistPath:[NSString stringWithFormat:@"%@/Config/Project.plist", self.path] withVariables:@{
        @"SRCROOT": path,
        @"SDKROOT": [[Bootstrap shared] sdkPath],
        @"BSROOT": [[Bootstrap shared] bootstrapPath:@"/"],
        @"CACHEROOT": _cachePath
    }];
    _entitlementsConfig = [[NXEntitlementsConfig alloc] initWithPlistPath:[NSString stringWithFormat:@"%@/Config/Entitlements.plist", self.path] withVariables:nil];
    return self;
}

+ (instancetype)projectWithPath:(NSString*)path
{
    return [[NXProject alloc] initWithPath:path];
}

+ (instancetype)createProjectAtPath:(NSString*)path
                           withName:(NSString*)name
               withBundleIdentifier:(NSString*)bundleid
                           withType:(NXProjectType)type
                       withLanguage:(NXCodeTemplateLanguage)language
{
    NSString *projectPath = [NSString stringWithFormat:@"%@/%@", path, [[NSUUID UUID] UUIDString]];
    NSFileManager *defaultFileManager = [NSFileManager defaultManager];
    
    NSMutableArray *directoryList = [NSMutableArray arrayWithArray:@[@"",@"/Config"]];
    if(type == NXProjectTypeApp)
    {
        [directoryList addObject:@"/Resources"];
    }
    for(NSString *directory in directoryList)
    {
        NSError *error = nil;
        [defaultFileManager createDirectoryAtPath:[NSString stringWithFormat:@"%@%@", projectPath, directory] withIntermediateDirectories:NO attributes:NULL error:&error];
        if(error)
        {
            [defaultFileManager removeItemAtPath:projectPath error:nil];
            return nil;
        }
    }
    
    NSDictionary *entitlementsPlist = @{
#if !JAILBREAK_ENV
        @"com.nyxian.pe.get_task_allowed": @(YES),
        @"com.nyxian.pe.task_for_pid": @(NO),
        @"com.nyxian.pe.process_enumeration": @(NO),
        @"com.nyxian.pe.process_kill": @(NO),
        @"com.nyxian.pe.process_spawn": @(NO),
        @"com.nyxian.pe.process_spawn_signed_only": @(NO),
        @"com.nyxian.pe.process_spawn_inherite_entitlements": @(NO),
        @"com.nyxian.pe.process_elevate": @(NO),
        @"com.nyxian.pe.host_manager": @(NO),
        @"com.nyxian.pe.launch_services_get_endpoint": @(NO),
        @"com.nyxian.pe.launch_services_set_endpoint": @(NO),
        @"com.nyxian.pe.dyld_hide_liveprocess": @(YES),
        @"com.nyxian.pe.platform": @(NO),
        @"com.nyxian.pe.platform_root": @(NO)
#else
        @"platform-application": @(YES)
#endif // !JAILBREAK_ENV
    };
    
    NSDictionary *projConfigPlist = nil;
    switch(type)
    {
        case NXProjectTypeApp:
            projConfigPlist = @{
                @"NXProjectFormat": @"NXFalcon",
                @"LDEExecutable": name,
                @"LDEDisplayName": name,
                @"LDEBundleIdentifier": bundleid,
                @"LDEBundleInfo": @{
                    @"UIApplicationSceneManifest": @{
                        @"UIApplicationSupportsMultipleScenes": @(NO),
                        @"UISceneConfigurations": @{
                            @"UIWindowSceneSessionRoleApplication": @[
                                @{
                                    @"UISceneConfigurationName": @"Default Configuration",
                                    @"UISceneDelegateClassName": @"SceneDelegate"
                                }
                            ]
                        }
                    }
                },
                @"LDEBundleVersion": @"1.0",
                @"LDEBundleShortVersion": @"1.0",
                @"LDEProjectType": @(type),
                @"LDEVersion": NXOSVersion.maximumBuildVersion.versionString,
                @"LDEMinimumVersion": NXOSVersion.hostVersion.pickerVersionString ?: NXOSVersion.maximumBuildVersion.versionString,
                @"LDECompilerFlags": @[
                    @"-target",
                    @"arm64-apple-ios$(LDEMinimumVersion)",
                    @"-isysroot",
                    @"$(SDKROOT)",
                    @"-resource-dir",
                    @"$(BSROOT)/Include",
                    @"-fobjc-arc"
                ],
                @"LDELinkerFlags": @[
                    @"-platform_version",
                    @"ios",
                    @"$(LDEMinimumVersion)",
                    @"$(LDEVersion)",
                    @"-arch",
                    @"arm64",
                    @"-syslibroot",
                    @"$(SDKROOT)",
                    @"-L$(BSROOT)/lib",
                    @"-ObjC",
                    @"-lc",
                    @"-lclang_rt.ios",
                    @"-framework",
                    @"Foundation",
                    @"-framework",
                    @"UIKit"
                ],
                @"LDEOutputPath": @"$(CACHEROOT)/Payload/$(LDEDisplayName).app/$(LDEExecutable)",
            };
            break;
        case NXProjectTypeUtility:
            projConfigPlist = @{
                @"NXProjectFormat": @"NXFalcon",
                @"LDEExecutable": name,
                @"LDEDisplayName": name,
                @"LDEProjectType": @(type),
                @"LDEVersion": NXOSVersion.maximumBuildVersion.versionString,
                @"LDEMinimumVersion": NXOSVersion.hostVersion.pickerVersionString ?: NXOSVersion.maximumBuildVersion.versionString,
                @"LDECompilerFlags": NXCompilerFlagsForCodeTemplateLanguage(language),
                @"LDELinkerFlags": NXLinkerFlagsForCodeTemplateLanguage(language),
                @"LDEOutputPath": @"$(CACHEROOT)/$(LDEExecutable)",
            };
            break;
        default:
            projConfigPlist = @{
                @"LDEDisplayName": name,
                @"LDEProjectType": @(type)
            };
            break;
    }
    
    NSDictionary *plistList = @{
        @"/Config/Project.plist": projConfigPlist,
        @"/Config/Entitlements.plist": entitlementsPlist
    };
    
    for(NSString *key in plistList)
    {
        NSError *error;
        NSDictionary *plistItem = plistList[key];
        NSData *plistData = [NSPropertyListSerialization dataWithPropertyList:plistItem format:NSPropertyListXMLFormat_v1_0 options:0 error:&error];
        [plistData writeToFile:[NSString stringWithFormat:@"%@%@", projectPath, key] atomically:YES];
        
        if(error)
        {
            [defaultFileManager removeItemAtPath:projectPath error:nil];
            return nil;
        }
    }
    
    NXCodeTemplateScheme scheme = NXCodeTemplateSchemeFromProjectType(type);
    if(scheme == NXCodeTemplateSchemeInvalid)
    {
        [[NSFileManager defaultManager] removeItemAtPath:projectPath error:nil];
        return nil;
    }
    
    if(!NXCodeTemplateMakeProjectStructure(scheme, language, name, projectPath))
    {
        [[NSFileManager defaultManager] removeItemAtPath:projectPath error:nil];
        return nil;
    }
    
    return [NXProject projectWithPath:projectPath];
}

+ (NSMutableDictionary<NSString*,NSMutableArray<NXProject*>*>*)listProjectsAtPath:(NSString*)path
{
    NSMutableDictionary<NSString*,NSMutableArray<NXProject*>*> *projectList = [[NSMutableDictionary alloc] init];
    
    NSMutableArray<NXProject*> *applicationProjects = [[NSMutableArray alloc] init];
    NSMutableArray<NXProject*> *utilityProjects = [[NSMutableArray alloc] init];
    NSMutableArray<NXProject*> *unknownProjects = [[NSMutableArray alloc] init];
    
    projectList[@"applications"] = applicationProjects;
    projectList[@"utilities"] = utilityProjects;
    projectList[@"unknown"] = unknownProjects;
    
    NSError *error;
    NSArray *pathEntries = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:&error];
    if(error) return projectList;
    for(NSString *entry in pathEntries)
    {
        NXProject *project = [[NXProject alloc] initWithPath:[NSString stringWithFormat:@"%@/%@",path,entry]];
        
        if(project.projectConfig.type == NXProjectTypeApp)
        {
            [applicationProjects addObject:project];
        }
        else if(project.projectConfig.type == NXProjectTypeUtility)
        {
            [utilityProjects addObject:project];
        }
        else
        {
            [unknownProjects addObject:project];
        }
    }
    
    return projectList;
}

- (void)removeProject
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:self.cachePath error:nil];
    [fileManager removeItemAtPath:self.path error:nil];
}

- (NSString*)resourcesPath { return [NSString stringWithFormat:@"%@/Resources", self.path]; }
- (NSString*)payloadPath { return [NSString stringWithFormat:@"%@/Payload", self.cachePath]; }
- (NSString*)bundlePath { return [NSString stringWithFormat:@"%@/%@.app", [self payloadPath], [[self projectConfig] executable]]; }
- (NSString*)machoPath {
    if(self.projectConfig.projectFormat == NXProjectFormatKate)
    {
    kate_handling:
        if(self.projectConfig.type == NXProjectTypeApp)
        {
            return [NSString stringWithFormat:@"%@/%@", [self bundlePath], [[self projectConfig] executable]];
        }
        else
        {
            return [NSString stringWithFormat:@"%@/%@", [self cachePath], [[self projectConfig] executable]];
        }
    }
    else
    {
        NSString *outputPath = [[self projectConfig] outputPath];
        if(outputPath == nil || ![outputPath isKindOfClass:[NSString class]])
        {
            goto kate_handling;
        }
        return outputPath;
    }
}
- (NSString*)packagePath { return [NSString stringWithFormat:@"%@/%@.ipa", self.cachePath, [[self projectConfig] executable]]; }
- (NSString*)homePath { return [NSString stringWithFormat:@"%@/data", self.cachePath]; }
- (NSString*)temporaryPath { return [NSString stringWithFormat:@"%@/data/tmp", self.cachePath]; }
- (NSString*)uuid { return [[NSURL fileURLWithPath:self.path] lastPathComponent]; }

- (BOOL)reload
{
    return [[self entitlementsConfig] reloadIfNeeded] | [[self projectConfig] reloadIfNeeded];
}

@end
