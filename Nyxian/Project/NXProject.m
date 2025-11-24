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

#import <Project/NXProject.h>
#import <LindChain/Core/LDEThreadControl.h>
#import <Project/NXCodeTemplate.h>
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
- (NSString*)platformMinimumVersion { return [self readStringForKey:@"LDEMinimumVersion" withDefaultValue:@"1.0"]; }
- (int)type { return (int)[self readIntegerForKey:@"LDEProjectType" withDefaultValue:NXProjectTypeApp]; }
- (int)threads
{
    const int maxThreads = [LDEThreadControl getOptimalThreadCount];
    int pthreads = (int)[self readIntegerForKey:@"LDEOverwriteThreads" withDefaultValue:[LDEThreadControl getUserSetThreadCount]];
    if(pthreads == 0)
        pthreads = [LDEThreadControl getUserSetThreadCount];
    else if(pthreads > maxThreads)
        pthreads = maxThreads;
    return pthreads;
}

- (BOOL)increment {
    NSNumber *value = [self readKey:@"LDEOverwriteIncrementalBuild"];
    NSNumber *userSetValue = [[NSUserDefaults standardUserDefaults] objectForKey:@"LDEIncrementalBuild"];
    return value ? value.boolValue : userSetValue ? userSetValue.boolValue : YES;
}

- (NSMutableArray*)generateCompilerFlags
{
    NSMutableArray *flags = [[NSMutableArray alloc] initWithArray:[self compilerFlags]];
    
    [flags addObjectsFromArray:@[
        @"-g",
        @"-target",
        [self platformTriple],
        @"-isysroot",
        [[Bootstrap shared] bootstrapPath:@"/SDK/iPhoneOS26.1.sdk"],
        [NSString stringWithFormat:@"-F%@/System/Library/SubFrameworks", [[Bootstrap shared] bootstrapPath:@"/SDK/iPhoneOS26.1.sdk"]],
        [NSString stringWithFormat:@"-F%@/System/Library/PrivateFrameworks", [[Bootstrap shared] bootstrapPath:@"/SDK/iPhoneOS26.1.sdk"]],
        [NSString stringWithFormat:@"-I%@", [[Bootstrap shared] bootstrapPath:@"/Include/include"]]
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
                    @"LDEBundleInfo": @{},
                    @"LDEBundleVersion": @"1.0",
                    @"LDEBundleShortVersion": @"1.0",
                    @"LDEProjectType": @(type),
                    @"LDEMinimumVersion": [[UIDevice currentDevice] systemVersion],
                    @"LDECompilerFlags": @[@"-fobjc-arc"],
                    @"LDELinkerFlags": @[@"-ObjC", @"-lc", @"-lc++", @"-framework", @"Foundation", @"-framework", @"UIKit"]
                }
            };
            break;
        case NXProjectTypeUtility:
            plistList = @{
                @"/Config/Project.plist": @{
                    @"LDEExecutable": name,
                    @"LDEDisplayName": name,
                    @"LDEProjectType": @(type),
                    @"LDECompilerFlags": @[@"-fobjc-arc"],
                    @"LDELinkerFlags": @[@"-ObjC", @"-lc", @"-lc++", @"-framework", @"Foundation", @"-framework", @"UIKit"]
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
    return [[self projectConfig] reloadIfNeeded];
}

@end
