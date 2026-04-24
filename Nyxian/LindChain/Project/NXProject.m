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

+ (NSArray<NSString*>*)sdkCompilerFlags
{
    return @[
        @"-target",
        @"apple-arm64-ios26.4",
        @"-isysroot",
        NXBootstrap.shared.sdkURL.path,
        @"-resource-dir",
        [NXBootstrap.shared.rootURL URLByAppendingPathComponent:@"Include"].path
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
        _type = (NXProjectType)[self readIntegerForKey:@"LDEProjectType" withDefaultValue:NXProjectTypeApp];
        _executable = [self readSecureFromKey:@"LDEExecutable" withDefaultValue:@"Unknown"];
        _displayName = [self readSecureFromKey:@"LDEDisplayName" withDefaultValue:[self executable]];
        _bundleid = [self readSecureFromKey:@"LDEBundleIdentifier" withDefaultValue:[NSString stringWithFormat:@"app.nyxian.%@.%@", [[NXUser shared] username], [self executable]]];
        _version = [self readSecureFromKey:@"LDEBundleVersion" withDefaultValue:@"1.0"];
        _shortVersion = [self readSecureFromKey:@"LDEBundleShortVersion" withDefaultValue:[self version]];
        _infoDictionary = [self readSecureFromKey:@"LDEBundleInfo" withDefaultValue:@{}];
        _deploymentTarget = [self readSecureFromKey:@"LDEMinimumVersion" withDefaultValue:NXOSVersion.maximumBuildVersion.pickerVersionString];
        _outputPath = [self readKey:@"LDEOutputPath"];
        _signMachOWithNyxianEntitlements = [self readBooleanForKey:@"LDESignMachOWithNyxianEntitlements" withDefaultValue:true];
        
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
                [self readSecureFromKey:@"LDEOverwriteTriple" withDefaultValue:[NSString stringWithFormat:@"apple-arm64-ios%@", [self deploymentTarget]]],
                @"-isysroot",
                NXBootstrap.shared.sdkURL.path,
                [@"-L" stringByAppendingString:[NXBootstrap.shared.rootURL URLByAppendingPathComponent:@"lib"].path],
                @"-resource-dir",
                [NXBootstrap.shared.rootURL URLByAppendingPathComponent:@"Include"].path
            ]];
            
            _compilerFlags = array;
        }
        else
        {
            _compilerFlags = @[];
        }
        
        /* FIXME: as soon as switching to Swift LLVM this will not be necessary anymore */
        NSString *sysroot = nil;
        for(CFIndex i = 0; i < _compilerFlags.count; i++)
        {
            NSString *flag = _compilerFlags[i];
            if([flag isEqualToString:@"-isysroot"])
            {
                sysroot = _compilerFlags[i + 1];
                break;
            }
        }
        
        if(sysroot != nil)
        {
            _compilerFlags = [_compilerFlags arrayByAddingObject:[NSString stringWithFormat:@"-F%@/System/Library/SubFrameworks", sysroot]];
        }
        
        /* MARK: linker flags */
        _linkerFlags = [self readSecureFromKey:@"LDELinkerFlags" withDefaultValue:@[]];
        
        /* MARK: swift flags */
        _swiftFlags = [self readSecureFromKey:@"LDESwiftFlags" withDefaultValue:@[]];
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

- (instancetype)initWithURL:(NSURL*)url
{
    self = [super init];
    _url = url;
    _cacheURL = [NXBootstrap.shared.rootURL URLByAppendingPathComponent:[NSString stringWithFormat:@"/Cache/%@", [_url lastPathComponent]]];
    _projectConfig = [[NXProjectConfig alloc] initWithPlistPath:[NSString stringWithFormat:@"%@/Config/Project.plist", self.url.path] withVariables:@{
        @"SRCROOT": url.path,
        @"SDKROOT": NXBootstrap.shared.sdkURL.path,
        @"BSROOT": NXBootstrap.shared.rootURL.path,
        @"CACHEROOT": _cacheURL.path
    }];
    _entitlementsConfig = [[NXEntitlementsConfig alloc] initWithPlistPath:[NSString stringWithFormat:@"%@/Config/Entitlements.plist", self.url.path] withVariables:nil];
    return self;
}

+ (instancetype)projectWithURL:(NSURL*)url
{
    return [[NXProject alloc] initWithURL:url];
}

+ (instancetype)createProjectAtURL:(NSURL*)url
                          withName:(NSString*)name
              withBundleIdentifier:(NSString*)bundleid
                          withType:(NXProjectType)type
                      withLanguage:(NXCodeTemplateLanguage)language
{
    NSURL *projectURL = [url URLByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    NSFileManager *defaultFileManager = [NSFileManager defaultManager];
    
    NSMutableArray *directoryList = [NSMutableArray arrayWithArray:@[@"",@"/Config"]];
    if(type == NXProjectTypeApp)
    {
        [directoryList addObject:@"/Resources"];
    }
    for(NSString *directory in directoryList)
    {
        NSError *error = nil;
        [defaultFileManager createDirectoryAtURL:[projectURL URLByAppendingPathComponent:directory] withIntermediateDirectories:YES attributes:nil error:&error];
        if(error)
        {
            [defaultFileManager removeItemAtURL:projectURL error:nil];
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
        @"com.nyxian.pe.dyld_hide_liveprocess": @(NO),
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
                @"LDEMinimumVersion": NXOSVersion.hostVersion.pickerVersionString ?: NXOSVersion.maximumBuildVersion.versionString,
                @"LDECompilerFlags": @[
                    @"-target",
                    @"arm64-apple-ios$(LDEMinimumVersion)",
                    @"-isysroot",
                    @"$(SDKROOT)",
                    @"-resource-dir",
                    @"$(BSROOT)/Include",
                    @"-L$(BSROOT)/lib",
                    @"-lclang_rt.ios",
                    @"-fobjc-arc",
                    @"-framework",
                    @"Foundation",
                    @"-framework",
                    @"UIKit"
                ],
                @"LDELinkerFlags": @[],
                @"LDESwiftFlags": NXSwiftFlagsForCodeTemplateLanguage(language),
                @"LDEOutputPath": @"$(CACHEROOT)/Payload/$(LDEDisplayName).app/$(LDEExecutable)",
            };
            break;
        case NXProjectTypeUtility:
            projConfigPlist = @{
                @"NXProjectFormat": @"NXFalcon",
                @"LDEExecutable": name,
                @"LDEDisplayName": name,
                @"LDEProjectType": @(type),
                @"LDEMinimumVersion": NXOSVersion.hostVersion.pickerVersionString ?: NXOSVersion.maximumBuildVersion.versionString,
                @"LDECompilerFlags": NXCompilerFlagsForCodeTemplateLanguage(language),
                @"LDELinkerFlags": @[],
                @"LDESwiftFlags": NXSwiftFlagsForCodeTemplateLanguage(language),
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
        [plistData writeToURL:[projectURL URLByAppendingPathComponent:key] atomically:YES];
        
        if(error)
        {
            [defaultFileManager removeItemAtURL:projectURL error:nil];
            return nil;
        }
    }
    
    NXCodeTemplateScheme scheme = NXCodeTemplateSchemeFromProjectType(type);
    if(scheme == NXCodeTemplateSchemeInvalid)
    {
        [[NSFileManager defaultManager] removeItemAtURL:projectURL error:nil];
        return nil;
    }
    
    if(!NXCodeTemplateMakeProjectStructure(scheme, language, name, projectURL))
    {
        [[NSFileManager defaultManager] removeItemAtURL:projectURL error:nil];
        return nil;
    }
    
    return [NXProject projectWithURL:projectURL];
}

+ (NSMutableDictionary<NSString*,NSMutableArray<NXProject*>*>*)listProjectsAtURL:(NSURL*)url
{
    NSMutableDictionary<NSString*,NSMutableArray<NXProject*>*> *projectList = [[NSMutableDictionary alloc] init];
    
    NSMutableArray<NXProject*> *applicationProjects = [[NSMutableArray alloc] init];
    NSMutableArray<NXProject*> *utilityProjects = [[NSMutableArray alloc] init];
    NSMutableArray<NXProject*> *unknownProjects = [[NSMutableArray alloc] init];
    
    projectList[@"applications"] = applicationProjects;
    projectList[@"utilities"] = utilityProjects;
    projectList[@"unknown"] = unknownProjects;
    
    NSError *error;
    NSArray<NSURL*> *urlEntries = [[NSFileManager defaultManager] contentsOfDirectoryAtURL:url includingPropertiesForKeys:nil options:0 error:&error];
    if(error)
    {
        return projectList;
    }
    
    for(NSURL *entry in urlEntries)
    {
        NXProject *project = [NXProject projectWithURL:entry];
        
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
    [fileManager removeItemAtURL:self.cacheURL error:nil];
    [fileManager removeItemAtURL:self.url error:nil];
}

- (NSURL*)resourcesURL { return [self.url URLByAppendingPathComponent:@"Resources"]; }
- (NSURL*)payloadURL { return [self.cacheURL URLByAppendingPathComponent:@"Payload"]; }
- (NSURL*)bundleURL { return [self.payloadURL URLByAppendingPathComponent:[self.projectConfig.executable stringByAppendingPathExtension:@"app"]]; }
- (NSURL*)machoURL
{
    if(self.projectConfig.projectFormat == NXProjectFormatKate)
    {
    kate_handling:
        if(self.projectConfig.type == NXProjectTypeApp)
        {
            return [self.bundleURL URLByAppendingPathComponent:self.projectConfig.executable];
        }
        else
        {
            return [self.cacheURL URLByAppendingPathComponent:self.projectConfig.executable];
        }
    }
    else
    {
        NSString *outputPath = [[self projectConfig] outputPath];
        if(outputPath == nil || ![outputPath isKindOfClass:[NSString class]])
        {
            goto kate_handling;
        }
        return [NSURL fileURLWithPath:outputPath];
    }
}
- (NSURL*)packageURL { return [self.cacheURL URLByAppendingPathComponent:[self.projectConfig.executable stringByAppendingPathExtension:@"ipa"]]; }

- (BOOL)reload
{
    return [[self entitlementsConfig] reloadIfNeeded] | [[self projectConfig] reloadIfNeeded];
}

@end
