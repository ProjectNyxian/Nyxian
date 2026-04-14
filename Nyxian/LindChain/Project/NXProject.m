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

- (NXProjectFormat)projectFormat
{
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
        return NXProjectFormatKate;
    }
    else if([projectFormat isEqualToString:@"NXFalcon"] ||
            [projectFormat isEqualToString:@"NXFalconV1"])
    {
        return NXProjectFormatFalconV1;
    }
    else if([projectFormat isEqualToString:@"NXFalconV2"])
    {
        return NXProjectFormatFalconV2;
    }
    
    return NXProjectFormatDefault;
}

- (NSString*)executable { return [self readSecureFromKey:@"LDEExecutable" withDefaultValue:@"Unknown"]; }
- (NSString*)displayName { return [self readSecureFromKey:@"LDEDisplayName" withDefaultValue:[self executable]]; }
- (NSString*)bundleid { return [self readSecureFromKey:@"LDEBundleIdentifier" withDefaultValue:[NSString stringWithFormat:@"app.nyxian.%@.%@", [[NXUser shared] username], [self executable]]]; }
- (NSString*)version { return [self readSecureFromKey:@"LDEBundleVersion" withDefaultValue:@"1.0"]; }
- (NSString*)shortVersion { return [self readSecureFromKey:@"LDEBundleShortVersion" withDefaultValue:[self version]]; }
- (NSDictionary*)infoDictionary { return [self readSecureFromKey:@"LDEBundleInfo" withDefaultValue:@{}]; }

- (NSArray*)compilerFlags
{
    NSArray *compilerFlags = [self readSecureFromKey:@"LDECompilerFlags" withDefaultValue:@[]];
    
    if([self projectFormat] == NXProjectFormatFalconV2)
    {
        return compilerFlags;
    }
    else if([self projectFormat] == NXProjectFormatFalconV1)
    {
        /*
         * if we don't filter some linker flags then
         * the translation breaks.
         */
        NSArray *linkerFlags = [self readSecureFromKey:@"LDELinkerFlags" withDefaultValue:@[]];
        NSMutableArray *filteredLinker = [NSMutableArray array];
        NSSet *skipArgs = [NSSet setWithObjects:@"-syslibroot", @"-platform_version", nil];
        for(NSUInteger i = 0; i < linkerFlags.count; i++)
        {
            NSString *flag = linkerFlags[i];
            if([skipArgs containsObject:flag])
            {
                NSUInteger skip = [flag isEqualToString:@"-platform_version"] ? 3 : 1;
                i += skip;
                continue;
            }
            [filteredLinker addObject:flag];
        }
        return [compilerFlags arrayByAddingObjectsFromArray:filteredLinker];
    }
    else if([self projectFormat] == NXProjectFormatKate)
    {
        /* FIXME: compiler and linker flags are now merged */
        
        NSMutableArray *array = [compilerFlags mutableCopy];
        
        [array addObjectsFromArray:@[
            @"-target",
            [self readSecureFromKey:@"LDEOverwriteTriple" withDefaultValue:[NSString stringWithFormat:@"apple-arm64-ios%@", [self platformMinimumVersion]]],
            @"-isysroot",
            [[Bootstrap shared] sdkPath],
            [@"-F" stringByAppendingString:[[Bootstrap shared] sdkPath:@"/System/Library/SubFrameworks"]],
            [@"-F" stringByAppendingString:[[Bootstrap shared] sdkPath:@"/System/Library/PrivateFrameworks"]],
            @"-resource-dir",
            [[Bootstrap shared] bootstrapPath:@"/Include"]
        ]];
        
        return array;
    }
    
    return @[];
}

- (NSString*)platformMinimumVersion { return [self readSecureFromKey:@"LDEMinimumVersion" withDefaultValue:@"17.0"]; }
- (int)type { return (int)[self readIntegerForKey:@"LDEProjectType" withDefaultValue:NXProjectTypeApp]; }
- (int)threads
{
    const int maxThreads = LDEGetOptimalThreadCount();
    int pthreads = (int)[self readIntegerForKey:@"LDEOverwriteThreads" withDefaultValue:LDEGetUserSetThreadCount()];
    
    if(pthreads == 0)
    {
        pthreads = LDEGetUserSetThreadCount();
    }
    else if(pthreads > maxThreads)
    {
        pthreads = maxThreads;
    }
    
    return pthreads;
}

- (BOOL)increment
{
    NSNumber *value = [self readKey:@"LDEOverwriteIncrementalBuild"];
    NSNumber *userSetValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"LDEIncrementalBuild"];
    return value ? value.boolValue : userSetValue ? userSetValue.boolValue : YES;
}

- (NSString*)outputPath
{
    return [self readKey:@"LDEOutputPath"];
}

+ (NSArray*)sdkCompilerFlags
{
    return @[
        @"-target",
        @"apple-arm64-ios26.4",
        @"-isysroot",
        [[Bootstrap shared] sdkPath],
        [@"-F" stringByAppendingString:[[Bootstrap shared] sdkPath:@"/System/Library/SubFrameworks"]],
        [@"-F" stringByAppendingString:[[Bootstrap shared] sdkPath:@"/System/Library/PrivateFrameworks"]],
        @"-resource-dir",
        [[Bootstrap shared] bootstrapPath:@"/Include"]
    ];
}

@end

@implementation NXEntitlementsConfig

- (BOOL)getTaskAllowed { return [self readBooleanForKey:@"com.nyxian.pe.get_task_allowed" withDefaultValue:YES]; }
- (BOOL)taskForPid { return [self readBooleanForKey:@"com.nyxian.pe.task_for_pid" withDefaultValue:NO]; }
- (BOOL)taskForPidHost { return [self readBooleanForKey:@"com.nyxian.pe.task_for_pid_host" withDefaultValue:NO]; }
- (BOOL)processEnumeration { return [self readBooleanForKey:@"com.nyxian.pe.process_enumeration" withDefaultValue:NO]; }
- (BOOL)processKill { return [self readBooleanForKey:@"com.nyxian.pe.process_kill" withDefaultValue:NO]; }
- (BOOL)processSpawn { return [self readBooleanForKey:@"com.nyxian.pe.process_spawn" withDefaultValue:NO]; }
- (BOOL)processSpawnSignedOnly { return [self readBooleanForKey:@"com.nyxian.pe.process_spawn_signed_only" withDefaultValue:NO]; }
- (BOOL)processElevate { return [self readBooleanForKey:@"com.nyxian.pe.process_elevate" withDefaultValue:NO]; }
- (BOOL)hostManager { return [self readBooleanForKey:@"com.nyxian.pe.host_manager" withDefaultValue:NO]; }
- (BOOL)credManager { return [self readBooleanForKey:@"com.nyxian.pe.credentials_manager" withDefaultValue:NO]; }
- (BOOL)launchServiceStart { return [self readBooleanForKey:@"com.nyxian.pe.launch_services_start" withDefaultValue:NO]; }
- (BOOL)launchServiceStop { return [self readBooleanForKey:@"com.nyxian.pe.launch_services_stop" withDefaultValue:NO]; }
- (BOOL)launchServiceToggle { return [self readBooleanForKey:@"com.nyxian.pe.launch_services_toggle" withDefaultValue:NO]; }
- (BOOL)launchServiceGetEndpoint { return [self readBooleanForKey:@"com.nyxian.pe.launch_services_get_endpoint" withDefaultValue:NO]; }
- (BOOL)launchServiceSetEndpoint { return [self readBooleanForKey:@"com.nyxian.pe.launch_services_set_endpoint" withDefaultValue:NO]; }
- (BOOL)launchServiceManager { return [self readBooleanForKey:@"com.nyxian.pe.launch_services_manager" withDefaultValue:NO]; }
- (BOOL)dyldHideLiveProcess { return [self readBooleanForKey:@"com.nyxian.pe.dyld_hide_liveprocess" withDefaultValue:YES]; }
- (BOOL)processSpawnInheriteEntitlements { return [self readBooleanForKey:@"com.nyxian.pe.process_spawn_inherite_entitlements" withDefaultValue:NO]; }
- (BOOL)platform { return [self readBooleanForKey:@"com.nyxian.pe.platform" withDefaultValue:NO]; }
- (BOOL)platformRoot { return [self readBooleanForKey:@"com.nyxian.pe.platform_root" withDefaultValue:NO]; }

- (PEEntitlement)generateEntitlements
{
    PEEntitlement entitlements = 0;
    
    if([self getTaskAllowed]) entitlements |= PEEntitlementGetTaskAllowed;
    if([self taskForPid]) entitlements |= PEEntitlementTaskForPid;
    if([self processEnumeration]) entitlements |= PEEntitlementProcessEnumeration;
    if([self processKill]) entitlements |= PEEntitlementProcessKill;
    if([self processSpawn]) entitlements |= PEEntitlementProcessSpawn;
    if([self processSpawnSignedOnly]) entitlements |= PEEntitlementProcessSpawnSignedOnly;
    if([self processElevate]) entitlements |= PEEntitlementProcessElevate;
    if([self hostManager]) entitlements |= PEEntitlementHostManager;
    if([self credManager]) entitlements |= PEEntitlementCredentialsManager;
    if([self launchServiceStart]) entitlements |= PEEntitlementLaunchServicesStart;
    if([self launchServiceStop]) entitlements |= PEEntitlementLaunchServicesStop;
    if([self launchServiceToggle]) entitlements |= PEEntitlementLaunchServicesToggle;
    if([self launchServiceGetEndpoint]) entitlements |= PEEntitlementLaunchServicesGetEndpoint;
    if([self launchServiceSetEndpoint]) entitlements |= PEEntitlementLaunchServicesSetEndpoint;
    if([self launchServiceManager]) entitlements |= PEEntitlementLaunchServicesManager;
    if([self dyldHideLiveProcess]) entitlements |= PEEntitlementDyldHideLiveProcess;
    if([self processSpawnInheriteEntitlements]) entitlements |= PEEntitlementProcessSpawnInheriteEntitlements;
    if([self platform]) entitlements |= PEEntitlementPlatform;
    if([self platformRoot]) entitlements |= PEEntitlementPlatformRoot;
    
    return entitlements;
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
                @"NXProjectFormat": @"NXFalconV2",
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
                    @"-F$(SDKROOT)/System/Library/SubFrameworks",
                    @"-F$(SDKROOT)/System/Library/PrivateFrameworks",
                    @"-resource-dir",
                    @"$(BSROOT)/Include",
                    @"-fobjc-arc",
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
                @"NXProjectFormat": @"NXFalconV2",
                @"LDEExecutable": name,
                @"LDEDisplayName": name,
                @"LDEProjectType": @(type),
                @"LDEVersion": NXOSVersion.maximumBuildVersion.versionString,
                @"LDEMinimumVersion": NXOSVersion.hostVersion.pickerVersionString ?: NXOSVersion.maximumBuildVersion.versionString,
                @"LDECompilerFlags": NXCompilerFlagsForCodeTemplateLanguage(language),
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
    [[self entitlementsConfig] reloadIfNeeded];
    return [[self projectConfig] reloadIfNeeded];
}

@end
