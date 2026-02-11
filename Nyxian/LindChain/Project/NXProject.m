/*
 Copyright (C) 2025 cr4zyengineer

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#import <LindChain/Project/NXProject.h>
#import <LindChain/Utils/LDEThreadController.h>
#import <LindChain/Project/NXCodeTemplate.h>
#import <Nyxian-Swift.h>

@implementation NXProjectConfig

- (NSString*)executable { return [self readStringForKey:@"LDEExecutable" withDefaultValue:@"Unknown"]; }
- (NSString*)displayName { return [self readStringForKey:@"LDEDisplayName" withDefaultValue:[self executable]]; }
- (NSString*)bundleid { return [self readStringForKey:@"LDEBundleIdentifier" withDefaultValue:@"com.unknown.fallback.id"]; }
- (NSString*)version { return [self readStringForKey:@"LDEBundleVersion" withDefaultValue:@"1.0"]; }
- (NSString*)shortVersion { return [self readStringForKey:@"LDEBundleShortVersion" withDefaultValue:@"1.0"]; }
- (NSString*)platformTriple { return [self readStringForKey:@"LDEOverwriteTriple" withDefaultValue:[NSString stringWithFormat:@"apple-arm64-ios%@", [self platformMinimumVersion]]]; }
- (NSDictionary*)infoDictionary { return [self readSecureFromKey:@"LDEBundleInfo" withDefaultValue:[[NSDictionary alloc] init] classType:NSDictionary.class]; }
- (NSArray*)compilerFlags { return [self readArrayForKey:@"LDECompilerFlags" withDefaultValue:@[]]; }
- (NSArray*)linkerFlags { return [self readArrayForKey:@"LDELinkerFlags" withDefaultValue:@[]]; }
- (NSString*)platformMinimumVersion { return [self readStringForKey:@"LDEMinimumVersion" withDefaultValue:@"17.0"]; }
- (NSString*)platformVersion { return [self readStringForKey:@"LDEVersion" withDefaultValue:@"26.1"]; }
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

- (NSDictionary*)entitlements { return [self readSecureFromKey:@"LDEEntitlements" withDefaultValue:[[NSDictionary alloc] init] classType:NSDictionary.class]; }

- (BOOL)increment
{
    NSNumber *value = [self readKey:@"LDEOverwriteIncrementalBuild"];
    NSNumber *userSetValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"LDEIncrementalBuild"];
    return value ? value.boolValue : userSetValue ? userSetValue.boolValue : YES;
}

- (NSMutableArray*)generateCompilerFlags
{
    NSMutableArray *flags = [[NSMutableArray alloc] initWithArray:[self compilerFlags]];
    
    [flags addObjectsFromArray:@[
        @"-target",
        [self platformTriple],
        @"-isysroot",
        [[Bootstrap shared] bootstrapPath:@"/SDK/iPhoneOS26.1.sdk"],
        [@"-F" stringByAppendingString:[[Bootstrap shared] bootstrapPath:@"/SDK/iPhoneOS26.1.sdk/System/Library/SubFrameworks"]],
        [@"-F" stringByAppendingString:[[Bootstrap shared] bootstrapPath:@"/SDK/iPhoneOS26.1.sdk/System/Library/PrivateFrameworks"]],
        @"-resource-dir",
        [[Bootstrap shared] bootstrapPath:@"/Include"]
    ]];
    
    return flags;
}

- (NSMutableArray*)generateLinkerFlags
{
    NSMutableArray *flags = [[NSMutableArray alloc] initWithArray:[self linkerFlags]];
    
    [flags addObjectsFromArray:@[
        @"-platform_version",
        @"ios",
        [self platformMinimumVersion],
        [self platformVersion],
        @"-arch",
        @"arm64",
        @"-syslibroot",
        [[Bootstrap shared] bootstrapPath:@"/SDK/iPhoneOS26.1.sdk"],
        [@"-F" stringByAppendingString:[[Bootstrap shared] bootstrapPath:@"/SDK/iPhoneOS26.1.sdk/System/Library/SubFrameworks"]],
        [@"-F" stringByAppendingString:[[Bootstrap shared] bootstrapPath:@"/SDK/iPhoneOS26.1.sdk/System/Library/PrivateFrameworks"]],
        [@"-L" stringByAppendingString:[[Bootstrap shared] bootstrapPath:@"/lib"]]
    ]];
    
    return flags;
}

// NONE PUBLIC FEATURES - NOT READY FOR PUBLIC
- (BOOL)debug
{
    NSNumber *value = [self readKey:@"LDEDebug"];
    return value ? value.boolValue : NO;
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
- (BOOL)launchServiceManager { return [self readBooleanForKey:@"com.nyxian.pe.launch_services_manager" withDefaultValue:NO]; }
- (BOOL)trustCacheRead { return [self readBooleanForKey:@"com.nyxian.pe.trustcache_read" withDefaultValue:NO]; }
- (BOOL)trustCacheWrite { return [self readBooleanForKey:@"com.nyxian.pe.trustcache_write" withDefaultValue:NO]; }
- (BOOL)trustCacheManager { return [self readBooleanForKey:@"com.nyxian.pe.trustcache_manager" withDefaultValue:NO]; }
- (BOOL)enforceDeviceSpoof { return [self readBooleanForKey:@"com.nyxian.pe.enforce_device_spoof" withDefaultValue:NO]; }
- (BOOL)processSpawnInheriteEntitlements { return [self readBooleanForKey:@"com.nyxian.pe.process_spawn_inherite_entitlements" withDefaultValue:YES]; }
- (BOOL)platform { return [self readBooleanForKey:@"com.nyxian.pe.platform" withDefaultValue:NO]; }

- (PEEntitlement)generateEntitlements
{
    PEEntitlement entitlements = 0;
    
    if([self getTaskAllowed]) entitlements = entitlements | PEEntitlementGetTaskAllowed;
    if([self taskForPid]) entitlements = entitlements | PEEntitlementTaskForPid;
    if([self taskForPidHost]) entitlements = entitlements | PEEntitlementTaskForPidHost;
    if([self processEnumeration]) entitlements = entitlements | PEEntitlementProcessEnumeration;
    if([self processKill]) entitlements = entitlements | PEEntitlementProcessKill;
    if([self processSpawn]) entitlements = entitlements | PEEntitlementProcessSpawn;
    if([self processSpawnSignedOnly]) entitlements = entitlements | PEEntitlementProcessSpawnSignedOnly;
    if([self processElevate]) entitlements = entitlements | PEEntitlementProcessElevate;
    if([self hostManager]) entitlements = entitlements | PEEntitlementHostManager;
    if([self credManager]) entitlements = entitlements | PEEntitlementCredentialsManager;
    if([self launchServiceStart]) entitlements = entitlements | PEEntitlementLaunchServicesStart;
    if([self launchServiceStop]) entitlements = entitlements | PEEntitlementLaunchServicesStop;
    if([self launchServiceToggle]) entitlements = entitlements | PEEntitlementLaunchServicesToggle;
    if([self launchServiceGetEndpoint]) entitlements = entitlements | PEEntitlementLaunchServicesGetEndpoint;
    if([self launchServiceManager]) entitlements = entitlements | PEEntitlementLaunchServicesManager;
    if([self trustCacheRead]) entitlements = entitlements | PEEntitlementTrustCacheRead;
    if([self trustCacheWrite]) entitlements = entitlements | PEEntitlementTrustCacheWrite;
    if([self trustCacheManager]) entitlements = entitlements | PEEntitlementTrustCacheManager;
    if([self enforceDeviceSpoof]) entitlements = entitlements | PEEntitlementEnforceDeviceSpoof;
    if([self processSpawnInheriteEntitlements]) entitlements = entitlements | PEEntitlementProcessSpawnInheriteEntitlements;
    if([self platform]) entitlements = entitlements | PEEntitlementPlatform;
    
    return entitlements;
}

@end

/*
 Project
 */
@implementation NXProject

- (instancetype)initWithPath:(NSString*)path
{
    self = [super init];
    _path = path;
    _cachePath = [[Bootstrap shared] bootstrapPath:[NSString stringWithFormat:@"/Cache/%@", [self uuid]]];
    _projectConfig = [[NXProjectConfig alloc] initWithPlistPath:[NSString stringWithFormat:@"%@/Config/Project.plist", self.path]];
    _entitlementsConfig = [[NXEntitlementsConfig alloc] initWithPlistPath:[NSString stringWithFormat:@"%@/Config/Entitlements.plist", self.path]];
    return self;
}

+ (NXProject*)createProjectAtPath:(NSString*)path
                         withName:(NSString*)name
             withBundleIdentifier:(NSString*)bundleid
                         withType:(NXProjectType)type
{
    NSString *projectPath = [NSString stringWithFormat:@"%@/%@", path, [[NSUUID UUID] UUIDString]];
    
    NSFileManager *defaultFileManager = [NSFileManager defaultManager];
    
    NSMutableArray *directoryList = [NSMutableArray arrayWithArray:@[@"",@"/Config"]];
    if(type == NXProjectTypeApp)
    {
        [directoryList addObject:@"/Resources"];
    }
    for(NSString *directory in directoryList)
        [defaultFileManager createDirectoryAtPath:[NSString stringWithFormat:@"%@%@", projectPath, directory] withIntermediateDirectories:NO attributes:NULL error:nil];
    
    NSDictionary *plistList = nil;
    
    switch(type)
    {
        case NXProjectTypeApp:
            plistList = @{
                @"/Config/Project.plist": @{
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
                    @"LDEVersion": [[UIDevice currentDevice] systemVersion],
                    @"LDEMinimumVersion": [[UIDevice currentDevice] systemVersion],
                    @"LDECompilerFlags": @[@"-fobjc-arc"],
                    @"LDELinkerFlags": @[@"-ObjC", @"-lc", @"-framework", @"Foundation", @"-framework", @"UIKit", @"-lclang_rt.ios"],
                },
                @"/Config/Entitlements.plist": @{
#if !JAILBREAK_ENV
                    @"com.nyxian.pe.get_task_allowed": @(YES),
                    @"com.nyxian.pe.task_for_pid": @(NO),
                    @"com.nyxian.pe.task_for_pid_host": @(NO),
                    @"com.nyxian.pe.process_enumeration": @(NO),
                    @"com.nyxian.pe.process_kill": @(NO),
                    @"com.nyxian.pe.process_spawn": @(NO),
                    @"com.nyxian.pe.process_spawn_signed_only": @(NO),
                    @"com.nyxian.pe.process_spawn_inherite_entitlements": @(YES),
                    @"com.nyxian.pe.process_elevate": @(NO),
                    @"com.nyxian.pe.host_manager": @(NO),
                    @"com.nyxian.pe.launch_services_get_endpoint": @(NO),
                    @"com.nyxian.pe.dyld_hide_liveprocess": @(YES),
                    @"com.nyxian.pe.platform": @(NO)
#else
                    @"platform-application": @(YES)
#endif // !JAILBREAK_ENV
                }
            };
            break;
        case NXProjectTypeUtility:
            plistList = @{
                @"/Config/Project.plist": @{
                    @"LDEExecutable": name,
                    @"LDEDisplayName": name,
                    @"LDEProjectType": @(type),
                    @"LDECompilerFlags": @[],
                    @"LDELinkerFlags": @[@"-lc", @"-lclang_rt.ios"],
                    @"LDEVersion": [[UIDevice currentDevice] systemVersion],
                    @"LDEMinimumVersion": [[UIDevice currentDevice] systemVersion]
                },
                @"/Config/Entitlements.plist": @{
#if !JAILBREAK_ENV
                    @"com.nyxian.pe.get_task_allowed": @(YES),
                    @"com.nyxian.pe.task_for_pid": @(NO),
                    @"com.nyxian.pe.task_for_pid_host": @(NO),
                    @"com.nyxian.pe.process_enumeration": @(NO),
                    @"com.nyxian.pe.process_kill": @(NO),
                    @"com.nyxian.pe.process_spawn": @(NO),
                    @"com.nyxian.pe.process_spawn_signed_only": @(NO),
                    @"com.nyxian.pe.process_spawn_inherite_entitlements": @(YES),
                    @"com.nyxian.pe.process_elevate": @(NO),
                    @"com.nyxian.pe.host_manager": @(NO),
                    @"com.nyxian.pe.launch_services_get_endpoint": @(NO),
                    @"com.nyxian.pe.dyld_hide_liveprocess": @(YES),
                    @"com.nyxian.pe.platform": @(NO)
#else
                    @"platform-application": @(YES)
#endif // !JAILBREAK_ENV
                }
            };
            break;
        default:
            plistList = @{
                @"/Config/Project.plist": @{
                    @"LDEDisplayName": name,
                    @"LDEProjectType": @(type)
                }
            };
            break;
    }
    
    for(NSString *key in plistList)
    {
        NSDictionary *plistItem = plistList[key];
        NSData *plistData = [NSPropertyListSerialization dataWithPropertyList:plistItem format:NSPropertyListXMLFormat_v1_0 options:0 error:NULL];
        [plistData writeToFile:[NSString stringWithFormat:@"%@%@", projectPath, key] atomically:YES];
    }
    
    switch(type)
    {
        case NXProjectTypeApp:
            [[NXCodeTemplate shared] generateCodeStructureFromTemplateScheme:NXCodeTemplateSchemeApp withLanguage:NXCodeTemplateLanguageObjC withProjectName:name intoPath:projectPath];
            break;
        case NXProjectTypeUtility:
            [[NXCodeTemplate shared] generateCodeStructureFromTemplateScheme:NXCodeTemplateSchemeUtility withLanguage:NXCodeTemplateLanguageC withProjectName:name intoPath:projectPath];
            break;
        default:
            break;
    }
    
    return [[NXProject alloc] initWithPath:projectPath];
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

+ (void)removeProject:(NXProject*)project
{
    NSFileManager *fileManager = [NSFileManager defaultManager];
    [fileManager removeItemAtPath:project.cachePath error:nil];
    [fileManager removeItemAtPath:project.path error:nil];
}

- (NSString*)resourcesPath { return [NSString stringWithFormat:@"%@/Resources", self.path]; }
- (NSString*)payloadPath { return [NSString stringWithFormat:@"%@/Payload", self.cachePath]; }
- (NSString*)bundlePath { return [NSString stringWithFormat:@"%@/%@.app", [self payloadPath], [[self projectConfig] executable]]; }
- (NSString*)machoPath {
    if(self.projectConfig.type == NXProjectTypeApp)
    {
        return [NSString stringWithFormat:@"%@/%@", [self bundlePath], [[self projectConfig] executable]];
    }
    else
    {
        return [NSString stringWithFormat:@"%@/%@", [self cachePath], [[self projectConfig] executable]];
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
