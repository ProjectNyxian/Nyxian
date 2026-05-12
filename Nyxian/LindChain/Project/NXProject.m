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
        _organizationIdentifier = [self objectForKey:@"NXOrgIdentifier" withDefaultObject:@"com.example"];
        
        /* MARK: targets */
        NSArray *targetDicts = [self arrayForKey:@"NXProjectTargets" allowedTypes:[NSSet setWithArray:@[[NSDictionary class]]]];
        if(targetDicts == nil)
        {
            _targets = @[];
        }
        else
        {
            NSMutableArray *targets = [NSMutableArray array];
            for(NSDictionary *dict in targetDicts)
            {
                NXTarget *target = [NXTarget targetWithDictionary:dict];
                if(target != nil)
                {
                    [targets addObject:target];
                }
            }
            
            if(targets.count > 0)
            {
                NXTarget *target = targets.firstObject;
                _displayName = target.displayName;
                _bundleIdentifier = target.bundleIdentifier;
                _schemeKind = target.schemeKind;
            }
            _targets = targets;
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
    NSURL *targetURL = [projectURL URLByAppendingPathComponent:name];
    NSFileManager *defaultFileManager = [NSFileManager defaultManager];
    NSString *organizationIdentifierValue = organizationIdentifier ?: @"";
    NSString *bundleIdentifierValue = bundleid ?: @"";

    NSMutableArray *directoryList = [NSMutableArray arrayWithArray:@[@"",@"Config", name]];
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
            sceneDelegateClassName = [@"$(NXExecutable)." stringByAppendingString:sceneDelegateClassName];
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
    
    NSArray *frameworks = @[];
    
    switch(schemeKind)
    {
        case NXProjectSchemeKindApp:
            frameworks = @[
                @"Foundation",
                @"UIKit"
            ];
            break;
        case NXProjectSchemeKindUtility:
            frameworks = @[
                @"Foundation"
            ];
            break;
        default:
            [defaultFileManager removeItemAtURL:projectURL error:nil];
            return nil;
    }
    
    NXProjectScheme scheme = NXProjectSchemeFromSchemeKind(schemeKind);
    NXProjectLanguage language = NXProjectLanguageFromLanguageKind(languageKind);
    NXProjectInterface interface = NXProjectInterfaceFromInterfaceKind(interfaceKind);
    
    NSArray<NSString*> *array;
    if(!NXCodeTemplateMakeProjectStructure(scheme, language, interface, name, targetURL, &array))
    {
        [[NSFileManager defaultManager] removeItemAtURL:projectURL error:nil];
        return nil;
    }
    
    NSMutableDictionary *projConfigPlist = [NSMutableDictionary dictionaryWithDictionary:@{
        @"NXProjectFormat": NXProjectFormatAvisR2,
        @"NXOrgIdentifier": organizationIdentifierValue,
        @"NXProjectTargets": @[ /* first target is the one that runs */
            @{
                @"NXDisplayName": name,
                @"NXBundleName": name,
                @"NXBundleIdentifier": bundleIdentifierValue,
                @"NXScheme": NXProjectSchemeFromSchemeKind(schemeKind),
                @"NXDeploymentTarget": NXOSVersion.hostVersion.pickerVersionString ?: NXOSVersion.maximumBuildVersion.versionString,
                @"NXSourcePaths": array,
                @"NXFrameworks": frameworks,
                @"NXLibraries": @[
                    @"clang_rt.ios"
                ],
                @"NXBundleResourcesPaths": @[
                    [NSString stringWithFormat:@"$(SRCROOT)/%@/Info.plist", name],
                ]
            }
        ],
    }];
    
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
