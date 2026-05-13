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

#import <LindChain/Project/NXTarget.h>
#import <LindChain/Project/NXUser.h>
#import <NXBootstrap.h>
#import <Nyxian-Swift.h>

@implementation NXTarget

+ (instancetype)targetWithDictionary:(NSDictionary *)dictionary
{
    return [[self alloc] initWithDictionary:dictionary];
}

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    self = [super init];
    if(self)
    {
        NSArray<NSString*> *sourcePaths = [dictionary arrayForKey:@"NXSourcePaths" allowedTypes:[NSSet setWithArray:@[[NSString class]]]];
        NSArray<NSString*> *headerSearchPaths = [dictionary arrayForKey:@"NXHeaderSearchPaths" allowedTypes:[NSSet setWithArray:@[[NSString class]]]];
        NSArray<NSString*> *frameworkSearchPaths = [dictionary arrayForKey:@"NXFrameworkSearchPaths" allowedTypes:[NSSet setWithArray:@[[NSString class]]]];
        NSArray<NSString*> *librarySearchPaths = [dictionary arrayForKey:@"NXLibrarySearchPaths" allowedTypes:[NSSet setWithArray:@[[NSString class]]]];
        
        NSMutableArray<NSURL*> *sourceURLs = [NSMutableArray array];
        NSMutableArray<NSURL*> *headerSearchURLs = [NSMutableArray array];
        NSMutableArray<NSURL*> *frameworkSearchURLs = [NSMutableArray array];
        NSMutableArray<NSURL*> *librarySearchURLs = [NSMutableArray array];
        
        for(NSString *path in sourcePaths)
        {
            NSURL *url = [NSURL fileURLWithPath:path];
            if(url != nil)
            {
                [sourceURLs addObject:url];
            }
        }
        
        for(NSString *path in headerSearchPaths)
        {
            NSURL *url = [NSURL fileURLWithPath:path];
            if(url != nil)
            {
                [headerSearchURLs addObject:url];
            }
        }
        
        for(NSString *path in frameworkSearchPaths)
        {
            NSURL *url = [NSURL fileURLWithPath:path];
            if(url != nil)
            {
                [frameworkSearchURLs addObject:url];
            }
        }
        
        for(NSString *path in librarySearchPaths)
        {
            NSURL *url = [NSURL fileURLWithPath:path];
            if(url != nil)
            {
                [librarySearchURLs addObject:url];
            }
        }
        
        NSArray<NSString*> *bundleResourcesPaths = [dictionary arrayForKey:@"NXBundleResourcesPaths" allowedTypes:[NSSet setWithArray:@[[NSString class]]]];
        NSMutableArray<NSURL*> *bundleResourceURLs = [NSMutableArray array];
        for(NSString *path in bundleResourcesPaths)
        {
            NSURL *url = [NSURL fileURLWithPath:path];
            if(url != nil)
            {
                [bundleResourceURLs addObject:url];
            }
        }
        
        NXProjectScheme scheme = [dictionary objectForKey:@"NXScheme" withClass:[NSString class]];
        
        _schemeKind = NXProjectSchemeKindFromScheme(scheme);
        _bundleName = [dictionary objectForKey:@"NXBundleName" withDefaultObject:@"Unknown"];
        _displayName = [dictionary objectForKey:@"NXDisplayName" withDefaultObject:_bundleName];
        _bundleIdentifier = [dictionary objectForKey:@"NXBundleIdentifier" withDefaultObject:[NSString stringWithFormat:@"com.%@.%@", [[NXUser shared] username], _bundleName]];
        _bundleResourceURLs = bundleResourceURLs;
        _deploymentTarget = [dictionary objectForKey:@"NXDeploymentTarget" withDefaultObject:[[NXOSVersion maximumBuildVersion] versionString]];
        _sdkURL = [NSURL fileURLWithPath: [dictionary objectForKey:@"NXSDKPath" withDefaultObject:[[NXBootstrap shared] sdkURL].path]];
        _sourceURLs = sourceURLs;
        _headerSearchURLs = headerSearchURLs;
        _frameworkSearchURLs = frameworkSearchURLs;
        _librarySearchURLs = librarySearchURLs;
        _otherClangFlags = [dictionary arrayForKey:@"NXOtherClangFlags" allowedTypes:[NSSet setWithArray:@[[NSString class]]]];
        _otherSwiftFlags = [dictionary arrayForKey:@"NXOtherSwiftFlags" allowedTypes:[NSSet setWithArray:@[[NSString class]]]];
        _otherLinkerFlags = [dictionary arrayForKey:@"NXOtherLinkerFlags" allowedTypes:[NSSet setWithArray:@[[NSString class]]]];
        _frameworks = [dictionary arrayForKey:@"NXFrameworks" allowedTypes:[NSSet setWithArray:@[[NSString class]]]];
        _libraries = [dictionary arrayForKey:@"NXLibraries" allowedTypes:[NSSet setWithArray:@[[NSString class]]]];
        _dependentTargets = [dictionary arrayForKey:@"NXTargetDependency" allowedTypes:[NSSet setWithArray:@[[NSString class]]]];
        
        if(_schemeKind == NXProjectSchemeKindUnknown)
        {
            return nil;
        }
    }
    return self;
}

@end
