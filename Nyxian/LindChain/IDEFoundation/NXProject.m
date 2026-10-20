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

#import <LindChain/IDEFoundation/NXProject.h>
#import <LindChain/IDEFoundation/NXCodeTemplate.h>
#import <LindChain/IDEFoundation/NXUser.h>
#import <LindChain/IDEFoundation/NXUtils.h>
#import <Nyxian-Swift.h>

@implementation NXProjectConfig

+ (NSArray<NSString*>*)sdkCompilerFlags
{
    return @[
        @"-target",
        @"apple-arm64-ios27.0",
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
        _formatKind = NXProjectFormatKindFromFormat([self.dictionary objectForKey:@"NXProjectFormat" withDefaultObject:NXProjectFormatKate]);
        if(_formatKind <= NXProjectFormatKindAvisR1)
        {
            [self.dictionary remapKey:@"LDEMinimumVersion" toKey:@"NXDeploymentTarget"];
            [self.dictionary remapKey:@"LDEProjectType" toKey:@"NXProjectScheme" withRemapHandler:(id)^(id oldObj){
                if([oldObj isKindOfClass:[NSNumber class]])
                {
                    return NXProjectSchemeFromSchemeKind([(NSNumber*)oldObj integerValue]);
                }
                return NXProjectSchemeUnknown;
            }];
            [self.dictionary remapKey:@"LDEExecutable" toKey:@"NXExecutable"];
            [self.dictionary remapKey:@"LDEDisplayName" toKey:@"NXDisplayName"];
            [self.dictionary remapKey:@"LDEOrganizationPrefix" toKey:@"NXOrganizationPrefix"];
            [self.dictionary remapKey:@"LDEBundleIdentifier" toKey:@"NXBundleIdentifier"];
            [self.dictionary remapKey:@"LDEBundleVersion" toKey:@"NXBundleVersion"];
            [self.dictionary remapKey:@"LDEBundleShortVersion" toKey:@"NXBundleShortVersion"];
            [self.dictionary remapKey:@"LDEBundleInfo" toKey:@"NXBundleInfo"];
            [self.dictionary remapKey:@"LDEOutputPath" toKey:@"NXOutputPath"];
            [self.dictionary remapKey:@"LDESignMachOWithNyxianEntitlements" toKey:@"NXSignMachOWithNyxianEntitlements"];
            [self.dictionary remapKey:@"LDECompilerFlags" toKey:@"NXClangFlags"];
            [self.dictionary remapKey:@"LDELinkerFlags" toKey:@"NXLinkerFlags"];
        }
        
        _schemeKind = NXProjectSchemeKindFromScheme([self.dictionary objectForKey:@"NXProjectScheme" withClass:[NSString class]]);
        
        /* MARK: keys */
        _executable = [self.dictionary objectForKey:@"NXExecutable" withDefaultObject:@"Unknown"];
        _displayName = [self.dictionary objectForKey:@"NXDisplayName" withDefaultObject:[self executable]];
        _organizationPrefix = [self.dictionary objectForKey:@"NXOrganizationPrefix" withDefaultObject:@"com.example"];
        _bundleid = [self.dictionary objectForKey:@"NXBundleIdentifier" withDefaultObject:[NSString stringWithFormat:@"app.nyxian.%@.%@", [[NXUser shared] username], [self executable]]];
        _deploymentTarget = [self.dictionary objectForKey:@"NXDeploymentTarget" withDefaultObject:@"25.0"];
        _outputPath = [self.dictionary varObjectForKey:@"NXOutputPath"];
        _signMachOWithNyxianEntitlements = [self.dictionary booleanForKey:@"NXSignMachOWithNyxianEntitlements" withDefaultValue:YES];
        _linkFrameworksAutomatically = [self.dictionary booleanForKey:@"NXLinkFrameworksAutomatically" withDefaultValue:NO];
        
        /* MARK: info plist data */
        NSMutableDictionary *mutableInfoDictionary = [[self.dictionary objectForKey:@"NXBundleInfo" withDefaultObject:@{}] mutableCopy];
        if(_formatKind < NXProjectFormatKindAvisR2)
        {
            NSString *bundleVersion = [self.dictionary objectForKey:@"NXBundleVersion" withDefaultObject:@"1.0"];
            NSString *bundleShortVersion = [self.dictionary objectForKey:@"NXBundleShortVersion" withDefaultObject:bundleVersion];
            
            [mutableInfoDictionary addEntriesFromDictionary:@{
                @"CFBundleExecutable": _executable,
                @"CFBundleIdentifier": _bundleid,
                @"CFBundleName": _displayName,
                @"CFBundleVersion": bundleVersion,
                @"CFBundleShortVersionString": bundleShortVersion,
                @"MinimumOSVersion": _deploymentTarget,
                @"UIDeviceFamily": @[@(0), @(1)],
                @"UIRequiresFullScreen": @(NO),
                @"UISupportedInterfaceOrientations~ipad": @[
                    @"UIInterfaceOrientationPortrait",
                    @"UIInterfaceOrientationPortraitUpsideDown",
                    @"UIInterfaceOrientationLandscapeLeft",
                    @"UIInterfaceOrientationLandscapeRight"
                ]
            }];
        }
        _infoDictionary = mutableInfoDictionary;
        
        /* MARK: compiler flags */
        NSMutableArray *mutableCompilerFlags = [[self.dictionary arrayForKey:@"NXClangFlags" allowedTypes:[NSSet setWithArray:@[[NSString class]]]] mutableCopy];
        if(_formatKind <= NXProjectFormatKindKate)
        {
            [mutableCompilerFlags addObjectsFromArray:@[
                @"-target",
                [self.dictionary objectForKey:@"LDEOverwriteTriple" withDefaultObject:[NSString stringWithFormat:@"apple-arm64-ios%@", [self deploymentTarget]]],
                @"-isysroot",
                NXBootstrap.shared.sdkURL.path,
                [@"-L" stringByAppendingString:[NXBootstrap.shared.rootURL URLByAppendingPathComponent:@"lib"].path],
                @"-resource-dir",
                [NXBootstrap.shared.rootURL URLByAppendingPathComponent:@"Include"].path
            ]];
        }
        _compilerFlags = mutableCompilerFlags;
        
        /* MARK: linker flags */
        _linkerFlags = [self.dictionary arrayForKey:@"NXLinkerFlags" allowedTypes:[NSSet setWithArray:@[[NSString class]]]];
        
        /* MARK: swift flags */
        _swiftFlags = [self.dictionary arrayForKey:@"NXSwiftFlags" allowedTypes:[NSSet setWithArray:@[[NSString class]]]];
    }
    return reloaded;
}

@end

@implementation NXEntitlementsConfig
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
        @"NXROOT": NXBootstrap.shared.rootfsURL.path,
        @"CACHEROOT": _cacheURL.path,
        @"SHDROOT": [[NSBundle.mainBundle.bundleURL URLByAppendingPathComponent:@"Shared"] path],
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

    NSMutableDictionary *appBundleInfo = [@{
        @"CFBundleExecutable": @"$(NXExecutable)",
        @"CFBundleIdentifier": @"$(NXBundleIdentifier)",
        @"CFBundleName": @"$(NXDisplayName)",
        @"CFBundleVersion": @"$(NXBundleVersion)",
        @"CFBundleShortVersionString": @"$(NXBundleShortVersion)",
        @"MinimumOSVersion": @"$(NXDeploymentTarget)",
        @"UIDeviceFamily": @[@(1), @(2)],
        @"UIRequiresFullScreen": @(NO),
        @"UISupportedInterfaceOrientations~ipad": @[
            @"UIInterfaceOrientationPortrait",
            @"UIInterfaceOrientationPortraitUpsideDown",
            @"UIInterfaceOrientationLandscapeLeft",
            @"UIInterfaceOrientationLandscapeRight",
        ],
    } mutableCopy];
    
    if(interfaceKind == NXProjectInterfaceKindUIKit)
    {
        NSString *sceneDelegateClassName = @"SceneDelegate";
        if(languageKind == NXProjectLanguageKindSwift)
        {
            sceneDelegateClassName = [@"$(NXExecutable)." stringByAppendingString:sceneDelegateClassName];
        }
        
        [appBundleInfo addEntriesFromDictionary:@{
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
        }];
    }
    
    MDKOSVersion *version = MDKOSVersion.hostVersion;
    MDKOSVersion *minVer = [NXOSVersion.NXOSVersionSupportedBuildVersionsRaw firstObject];
    MDKOSVersion *maxVer = [NXOSVersion.NXOSVersionSupportedBuildVersionsRaw lastObject];
    if(minVer != NULL && maxVer != NULL)
    {
        MDKOSVersionRange range = {
            .minimumVersion = minVer,
            .maximumVersion = maxVer,
        };
        
        version = [MDKOSVersion versionForVersion:MDKOSVersion.hostVersion inVersionRange:range];
    }
    
    NSMutableDictionary *projConfigPlist = [NSMutableDictionary dictionaryWithDictionary:@{
        @"NXProjectFormat": NXProjectFormatAvisR2,
        @"NXProjectScheme": NXProjectSchemeFromSchemeKind(schemeKind),
        @"NXExecutable": name,
        @"NXDisplayName": name,
        @"NXOrganizationPrefix": organizationIdentifierValue,
        @"NXBundleIdentifier": bundleIdentifierValue,
        @"NXDeploymentTarget": version.versionString ?: @"27.0",
        @"NXClangFlags": NXCompilerFlagsForCodeTemplateLanguage(schemeKind, languageKind),
        @"NXLinkerFlags": @[],
        @"NXSwiftFlags": NXSwiftFlagsForCodeTemplateLanguage(schemeKind, languageKind),
        @"NXSignMachOWithNyxianEntitlements": @(YES),   /* FIXME: when enabled certain signers outside of zsign may fail to sign the MachO although its usually allowed to have trailing bits after the MachO ended, ldid has a weird non standard check that even is not inside of apples code sign cuz i tried to sign a MachO in strict mode and it passed including the trailing bits. */
        @"NXLinkFrameworksAutomatically": schemeKind == NXProjectSchemeKindKSurfaceKext ? @(NO) : @(YES),
    }];
    
    switch(schemeKind)
    {
        case NXProjectSchemeKindApp:
            [projConfigPlist setValuesForKeysWithDictionary:@{
                @"NXBundleInfo": appBundleInfo,
                @"NXBundleVersion": @"1.0",
                @"NXBundleShortVersion": @"1.0",
                @"NXOutputPath": @"$(CACHEROOT)/Payload/$(NXDisplayName).app/$(NXExecutable)"
            }];
            break;
        case NXProjectSchemeKindUtility:
            [projConfigPlist setValuesForKeysWithDictionary:@{
                @"NXOutputPath": @"$(CACHEROOT)/$(NXExecutable)"
            }];
            break;
        case NXProjectSchemeKindKSurfaceKext:
            [projConfigPlist setValuesForKeysWithDictionary:@{
                @"NXBundleInfo": @{
                    @"CFBundleExecutable": @"$(NXExecutable)",
                    @"CFBundleIdentifier": @"$(NXBundleIdentifier)",
                    @"CFBundleVersion": @"$(NXBundleVersion)",
                    @"CFBundleShortVersionString": @"$(NXBundleShortVersion)",
                },
                @"NXBundleVersion": @"1.0",
                @"NXBundleShortVersion": @"1.0",
                @"NXOutputPath": @"$(CACHEROOT)/Payload/$(NXBundleIdentifier).kext/$(NXExecutable)"
            }];
            [projConfigPlist removeObjectForKey:@"NXSignMachOWithNyxianEntitlements"];
            break;
        default:
            [defaultFileManager removeItemAtURL:projectURL error:nil];
            return nil;
    }
    
    NSMutableDictionary *plistList = [@{
        @"/Config/Project.plist": projConfigPlist,
        @"/Config/Entitlements.plist": @{
            /* foundational */
            (__bridge NSString*)kNXT2EntitlementPlatform: @(NO),
            (__bridge NSString*)kNXT2EntitlementPlatformRoot: @(NO),
            (__bridge NSString*)kNXT2EntitlementGetTaskAllow: @(YES),
            (__bridge NSString*)kNXT2EntitlementTaskForPid: @(NO),
            (__bridge NSString*)kNXT2EntitlementSUGID: @(NO),
            (__bridge NSString*)kNXT2EntitlementSystemTaskPorts: @(NO),
            
            /* process */
            (__bridge NSString*)kNXT2EntitlementProcessEnumeration: @(NO),
            (__bridge NSString*)kNXT2EntitlementProcessKill: @(NO),
            (__bridge NSString*)kNXT2EntitlementProcessSpawn: @(NO),
            (__bridge NSString*)kNXT2EntitlementProcessSpawnSignedOnly: @(NO),
            (__bridge NSString*)kNXT2EntitlementProcessSpawnInheriteEntitlements: @(NO),
            
            /* management */
            (__bridge NSString*)kNXT2EntitlementManagementHost: @(NO),
            
            /* launch services */
            (__bridge NSString*)kNXT2EntitlementLaunchServicesStart: @(NO),
            (__bridge NSString*)kNXT2EntitlementLaunchServicesStop: @(NO),
            (__bridge NSString*)kNXT2EntitlementLaunchServicesToggle: @(NO),
            (__bridge NSString*)kNXT2EntitlementLaunchServicesGetEndpoint: @(NO),
            (__bridge NSString*)kNXT2EntitlementLaunchServicesSetEndpoint: @(NO),
            (__bridge NSString*)kNXT2EntitlementLaunchServicesGetEndpointAllowList: @[],
            (__bridge NSString*)kNXT2EntitlementLaunchServicesSetEndpointAllowList: @[],
            
            /* sandbox */
            (__bridge NSString*)kNXT2EntitlementSandboxFileRead: @[],
            (__bridge NSString*)kNXT2EntitlementSandboxFileReadWrite: @[],
            (__bridge NSString*)kNXT2EntitlementSandboxNoContainer: @(NO),
        }
    } mutableCopy];
    
    if(schemeKind == NXProjectSchemeKindKSurfaceKext)
    {
        [plistList removeObjectForKey:@"/Config/Entitlements.plist"];
    }
    
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
    
    if(!NXCodeTemplateMakeProjectStructure(scheme, language, interface, name, projectURL, bundleid))
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
- (NSURL*)bundleURL {
    if(self.projectConfig.schemeKind == NXProjectSchemeKindKSurfaceKext)
    {
        return [self.payloadURL  URLByAppendingPathComponent:[self.projectConfig.bundleid stringByAppendingPathExtension:@"kext"]];
    }
    return [self.payloadURL URLByAppendingPathComponent:[self.projectConfig.executable stringByAppendingPathExtension:@"app"]];
}
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
- (NSURL*)packageURL {
    if(self.projectConfig.schemeKind == NXProjectSchemeKindKSurfaceKext)
    {
        return [self.cacheURL URLByAppendingPathComponent:[self.projectConfig.bundleid stringByAppendingPathExtension:@"kext.nipa"]];
    }
    return self.projectConfig.schemeKind == NXProjectSchemeKindApp ? [self.cacheURL URLByAppendingPathComponent:[self.projectConfig.executable stringByAppendingPathExtension:@"ipa"]] : self.machoURL;
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
