/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 cr4zyengineer
 Copyright (C) 2026 Kyle-Ye

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
#import <LindChain/Utils/Utils.h>
#import <LindChain/Project/NXCodeTemplate.h>
#import <LindChain/Project/NXUser.h>
#import <LindChain/Project/NXUtils.h>
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
        _formatKind = NXProjectFormatKindFromFormat([self objectForKey:@"NXProjectFormat" withDefaultObject:NXProjectFormatKate]);
        _schemeKind = NXProjectSchemeKindFromScheme([self objectForKey:@"NXProjectScheme" withClass:[NSString class]]);
        
        /* MARK: NXFalcon and below compatibility */
        if(_schemeKind == NXProjectSchemeKindUnknown)
        {
            _schemeKind = (NXProjectSchemeKind)[self integerForKey:@"LDEProjectType" withDefaultValue:NXProjectSchemeKindApp];
        }
        
        /* MARK: keys */
        _executable = [self objectForKey:@"LDEExecutable" withDefaultObject:@"Unknown"];
        _displayName = [self objectForKey:@"LDEDisplayName" withDefaultObject:[self executable]];
        _organizationPrefix = [self objectForKey:@"LDEOrganizationPrefix" withDefaultObject:@"com.example"];
        _bundleid = [self objectForKey:@"LDEBundleIdentifier" withDefaultObject:[NSString stringWithFormat:@"app.nyxian.%@.%@", [[NXUser shared] username], [self executable]]];
        _version = [self objectForKey:@"LDEBundleVersion" withDefaultObject:@"1.0"];
        _shortVersion = [self objectForKey:@"LDEBundleShortVersion" withDefaultObject:[self version]];
        _infoDictionary = [self objectForKey:@"LDEBundleInfo" withDefaultObject:@{}];
        _deploymentTarget = [self objectForKey:@"LDEMinimumVersion" withDefaultObject:NXOSVersion.maximumBuildVersion.pickerVersionString];
        _outputPath = [self objectForKey:@"LDEOutputPath"];
        _signMachOWithNyxianEntitlements = [self booleanForKey:@"LDESignMachOWithNyxianEntitlements" withDefaultValue:true];
        
        /* MARK: compiler flags */
        NSArray *compilerFlags = [self objectForKey:@"LDECompilerFlags" withDefaultObject:@[]];
        
        if(_formatKind == NXProjectFormatKindFalcon ||
           _formatKind == NXProjectFormatKindAvis)
        {
            _compilerFlags = compilerFlags;
        }
        else if(_formatKind == NXProjectFormatKindKate)
        {
            NSMutableArray *array = [compilerFlags mutableCopy];
            
            [array addObjectsFromArray:@[
                @"-target",
                [self objectForKey:@"LDEOverwriteTriple" withDefaultObject:[NSString stringWithFormat:@"apple-arm64-ios%@", [self deploymentTarget]]],
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
        _linkerFlags = [self objectForKey:@"LDELinkerFlags" withDefaultObject:@[]];
        
        /* MARK: swift flags */
        _swiftFlags = [self objectForKey:@"LDESwiftFlags" withDefaultObject:@[]];
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
        if([self booleanForKey:@"com.nyxian.pe.get_task_allowed" withDefaultValue:YES]) _entitlement |= PEEntitlementGetTaskAllowed;
        if([self booleanForKey:@"com.nyxian.pe.task_for_pid" withDefaultValue:NO]) _entitlement |= PEEntitlementTaskForPid;
        if([self booleanForKey:@"com.nyxian.pe.process_enumeration" withDefaultValue:NO]) _entitlement |= PEEntitlementProcessEnumeration;
        if([self booleanForKey:@"com.nyxian.pe.process_kill" withDefaultValue:NO]) _entitlement |= PEEntitlementProcessKill;
        if([self booleanForKey:@"com.nyxian.pe.process_spawn" withDefaultValue:NO]) _entitlement |= PEEntitlementProcessSpawn;
        if([self booleanForKey:@"com.nyxian.pe.process_spawn_signed_only" withDefaultValue:NO]) _entitlement |= PEEntitlementProcessSpawnSignedOnly;
        if([self booleanForKey:@"com.nyxian.pe.process_elevate" withDefaultValue:NO]) _entitlement |= PEEntitlementProcessElevate;
        if([self booleanForKey:@"com.nyxian.pe.host_manager" withDefaultValue:NO]) _entitlement |= PEEntitlementHostManager;
        if([self booleanForKey:@"com.nyxian.pe.credentials_manager" withDefaultValue:NO]) _entitlement |= PEEntitlementCredentialsManager;
        if([self booleanForKey:@"com.nyxian.pe.launch_services_start" withDefaultValue:NO]) _entitlement |= PEEntitlementLaunchServicesStart;
        if([self booleanForKey:@"com.nyxian.pe.launch_services_stop" withDefaultValue:NO]) _entitlement |= PEEntitlementLaunchServicesStop;
        if([self booleanForKey:@"com.nyxian.pe.launch_services_toggle" withDefaultValue:NO]) _entitlement |= PEEntitlementLaunchServicesToggle;
        if([self booleanForKey:@"com.nyxian.pe.launch_services_get_endpoint" withDefaultValue:NO]) _entitlement |= PEEntitlementLaunchServicesGetEndpoint;
        if([self booleanForKey:@"com.nyxian.pe.launch_services_set_endpoint" withDefaultValue:NO]) _entitlement |= PEEntitlementLaunchServicesSetEndpoint;
        if([self booleanForKey:@"com.nyxian.pe.launch_services_manager" withDefaultValue:NO]) _entitlement |= PEEntitlementLaunchServicesManager;
        if([self booleanForKey:@"com.nyxian.pe.dyld_hide_liveprocess" withDefaultValue:NO]) _entitlement |= PEEntitlementDyldHideLiveProcess;
        if([self booleanForKey:@"com.nyxian.pe.process_spawn_inherite_entitlements" withDefaultValue:NO]) _entitlement |= PEEntitlementProcessSpawnInheriteEntitlements;
        if([self booleanForKey:@"com.nyxian.pe.platform" withDefaultValue:NO]) _entitlement |= PEEntitlementPlatform;
        if([self booleanForKey:@"com.nyxian.pe.platform_root" withDefaultValue:NO]) _entitlement |= PEEntitlementPlatformRoot;
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
        withOrganizationIdentifier:(NSString*)organizationIdentifier
              withBundleIdentifier:(NSString*)bundleid
                    withSchemeKind:(NXProjectSchemeKind)schemeKind
                  withLanguageKind:(NXProjectLanguageKind)languageKind
                 withInterfaceKind:(NXProjectInterfaceKind)interfaceKind
{
    /* must always be valid */
    assert(NXProjectConfigurationIsValid(schemeKind, interfaceKind, languageKind));
    
    NSURL *projectURL = [url URLByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    NSFileManager *defaultFileManager = [NSFileManager defaultManager];
    NSString *organizationIdentifierValue = organizationIdentifier ?: @"";
    NSString *bundleIdentifierValue = bundleid ?: @"";

    NSMutableArray *directoryList = [NSMutableArray arrayWithArray:@[@"",@"/Config"]];
    if(schemeKind == NXProjectSchemeKindApp)
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

    NSDictionary *appBundleInfo = @{};
    if(interfaceKind == NXProjectInterfaceKindUIKit)
    {
        NSString *sceneDelegateClassName = @"SceneDelegate";
        if(languageKind == NXProjectLanguageKindSwift)
        {
            sceneDelegateClassName = [@"$(LDEExecutable)." stringByAppendingString:sceneDelegateClassName];
        }
        
        appBundleInfo = @{
            @"UIApplicationSceneManifest": @{
                @"UIApplicationSupportsMultipleScenes": @(NO),
                @"UISceneConfigurations": @{
                    @"UIWindowSceneSessionRoleApplication": @[
                        @{
                            @"UISceneConfigurationName": @"Default Configuration",
                            @"UISceneDelegateClassName": sceneDelegateClassName
                        }
                    ]
                }
            }
        };
    }
    
    NSMutableDictionary *projConfigPlist = [NSMutableDictionary dictionaryWithDictionary:@{
        @"NXProjectFormat": NXProjectFormatAvis,
        @"NXProjectScheme": NXProjectSchemeFromSchemeKind(schemeKind),
        @"LDEExecutable": name,
        @"LDEDisplayName": name,
        @"LDEOrganizationPrefix": organizationIdentifierValue,
        @"LDEBundleIdentifier": bundleIdentifierValue,
        @"LDEMinimumVersion": NXOSVersion.hostVersion.pickerVersionString ?: NXOSVersion.maximumBuildVersion.versionString,
        @"LDECompilerFlags": NXCompilerFlagsForCodeTemplateLanguage(schemeKind, languageKind),
        @"LDELinkerFlags": @[],
        @"LDESwiftFlags": NXSwiftFlagsForCodeTemplateLanguage(schemeKind, languageKind)
    }];
    
    switch(schemeKind)
    {
        case NXProjectSchemeKindApp:
            [projConfigPlist setValuesForKeysWithDictionary:@{
                @"LDEBundleInfo": appBundleInfo,
                @"LDEBundleVersion": @"1.0",
                @"LDEBundleShortVersion": @"1.0",
                @"LDEOutputPath": @"$(CACHEROOT)/Payload/$(LDEDisplayName).app/$(LDEExecutable)"
            }];
            break;
        case NXProjectSchemeKindUtility:
            [projConfigPlist setValuesForKeysWithDictionary:@{
                @"LDEOutputPath": @"$(CACHEROOT)/$(LDEExecutable)"
            }];
            break;
        default:
            [defaultFileManager removeItemAtURL:projectURL error:nil];
            return nil;
    }
    
    NSDictionary *plistList = @{
        @"/Config/Project.plist": projConfigPlist,
        @"/Config/Entitlements.plist": @{
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
        }
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
    
    NXProjectScheme scheme = NXProjectSchemeFromSchemeKind(schemeKind);
    NXProjectLanguage language = NXProjectLanguageFromLanguageKind(languageKind);
    NXProjectInterface interface = NXProjectInterfaceFromInterfaceKind(interfaceKind);
    
    if(!NXCodeTemplateMakeProjectStructure(scheme, language, interface, name, projectURL))
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
        
        if(project.projectConfig.schemeKind == NXProjectSchemeKindApp)
        {
            [applicationProjects addObject:project];
        }
        else if(project.projectConfig.schemeKind == NXProjectSchemeKindUtility)
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

- (BOOL)syncFolderStructureToCache
{
    NSFileManager *defaultManager = [NSFileManager defaultManager];
    
    BOOL(^directoryEnumeratorErrorHandler)(NSURL *url, NSError *error) = ^BOOL(NSURL *url, NSError *error){
        NSLog(@"skip %@: %@", url.path, error);
        return YES;
    };
    
    NSDirectoryEnumerator *sourceDirectoryEnumerator = [defaultManager enumeratorAtURL:self.url includingPropertiesForKeys:nil options:0 errorHandler:directoryEnumeratorErrorHandler];
    NSDirectoryEnumerator *destinationDirectoryEnumerator = [defaultManager enumeratorAtURL:self.cacheURL includingPropertiesForKeys:nil options:0 errorHandler:directoryEnumeratorErrorHandler];
    
    if(sourceDirectoryEnumerator == nil || destinationDirectoryEnumerator == nil)
    {
        return NO;
    }
    
    NSMutableSet<NSString*> *relativesShallExist = [NSMutableSet set];
    NSMutableSet<NSString*> *relativeObjectShallExist = [NSMutableSet set];
    
    /* capturing synchronisation */
    for(NSURL *url in sourceDirectoryEnumerator)
    {
        NSNumber *isDir;
        [url getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:NULL];
        if(isDir.boolValue)
        {
            [relativesShallExist addObject:NXRelativeURLFromBaseURLToFullURL(self.url, url).path];
        }
        else if([@[@"c",@"cpp",@"m",@"mm",@"swift"] containsObject:[url pathExtension]])
        {
            NSURL *relativeURL = NXRelativeURLFromBaseURLToFullURL(self.url, url);
            NSURL *objectFileURL = NXExpectedObjectFileURLForFileURL(relativeURL);
            [relativeObjectShallExist addObject:objectFileURL.path];
        }
    }
    
    /* applying synchronisation */
    for(NSURL *url in destinationDirectoryEnumerator)
    {
        NSNumber *isDir;
        [url getResourceValue:&isDir forKey:NSURLIsDirectoryKey error:NULL];
        if(isDir.boolValue && ![relativesShallExist containsObject:NXRelativeURLFromBaseURLToFullURL(self.cacheURL, url).path])
        {
            [defaultManager removeItemAtURL:url error:nil];
        }
        else if([@[@"o"] containsObject:[url pathExtension]])
        {
            NSURL *relativeURL = NXRelativeURLFromBaseURLToFullURL(self.cacheURL, url);
            if(![relativeObjectShallExist containsObject:relativeURL.path])
            {
                [defaultManager removeItemAtURL:url error:nil];
            }
        }
    }
    
    /* completing synchronisation */
    for(NSString *relative in relativesShallExist)
    {
        [defaultManager createDirectoryAtURL:[self.cacheURL URLByAppendingPathComponent:relative] withIntermediateDirectories:YES attributes:nil error:nil];
    }

    return YES;
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
    if(self.projectConfig.formatKind == NXProjectFormatKindKate)
    {
    kate_handling:
        if(self.projectConfig.schemeKind == NXProjectSchemeKindApp)
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
    /*
     * having to check weither cacheURL exists or nah,
     * if it doesn't we gonne have to create it.
     */
    BOOL isDirectory = YES;
    if(![[NSFileManager defaultManager] fileExistsAtPath:_cacheURL.path isDirectory:&isDirectory] || !isDirectory)
    {
        if(!isDirectory)
        {
            [[NSFileManager defaultManager] removeItemAtURL:_cacheURL error:nil];
        }
        
        [[NSFileManager defaultManager] createDirectoryAtURL:_cacheURL withIntermediateDirectories:YES attributes:nil error:nil];
        
    }
    
    return [[self entitlementsConfig] reloadIfNeeded] | [[self projectConfig] reloadIfNeeded];
}

@end
