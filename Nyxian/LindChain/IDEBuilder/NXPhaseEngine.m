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

#import <LindChain/IDEBuilder/NXPhaseEngine.h>
#import <LindChain/IDEBuilder/LDEFilesFinder.h>
#import <LindChain/IDEFoundation/NXUtils.h>

@implementation NXPhaseEngine

+ (instancetype)engineWithProject:(NXProject *)project
                            error:(NSError **)error
{
    /* finding code files */
    NSArray<NSString*> *swiftFiles = LDEFilesFinder(project.url.path, [NSSet setWithArray:@[@"swift"]], [NSSet setWithArray:@[@"Resources",@"Config"]]);
    NSArray<NSString*> *clangFiles = LDEFilesFinder(project.url.path, [NSSet setWithArray:@[@"c",@"cpp",@"m",@"mm"]], [NSSet setWithArray:@[@"Resources",@"Config"]]);
    if(swiftFiles == nil || clangFiles == nil)
    {
        if(error)
        {
            *error = [NSError errorWithDomain:@"org.emexlabs.nyxian.phaseengine" code:0 userInfo:@{ NSLocalizedDescriptionKey: @"Couldn't find code files, unknown error has occured." }];
        }
        return nil;
    }
    if([swiftFiles count] == 0 && [clangFiles count] == 0)
    {
        if(error)
        {
            *error = [NSError errorWithDomain:@"org.emexlabs.nyxian.phaseengine" code:0 userInfo:@{ NSLocalizedDescriptionKey: @"Nothing to build. No code files were found, please create a code file." }];
        }
        return nil;
    }
    
    /* crafting driver flags */
    NSMutableArray *driverFlags = [[NSMutableArray alloc] init];
    if(driverFlags == nil)
    {
        if(error)
        {
            *error = [NSError errorWithDomain:@"org.emexlabs.nyxian.phaseengine" code:0 userInfo:@{ NSLocalizedDescriptionKey: @"Out of memory." }];
        }
        return nil;
    }
    
    [driverFlags addObjectsFromArray:swiftFiles];
    [driverFlags addObjectsFromArray:clangFiles];
    [driverFlags addObject:@"-o"];
    [driverFlags addObject:project.machoURL.path];
    
    /* crafting phase engine */
    if([swiftFiles count] != 0)
    {
        [driverFlags addObjectsFromArray:project.projectConfig.swiftFlags];
        [driverFlags addObject:@"-module-name"];
        [driverFlags addObject:NXMakeContentCodeFriendly(project.projectConfig.displayName)];
        return [self engineWithSwiftFlags:driverFlags withOtherClangFlags:project.projectConfig.compilerFlags withOtherLinkerFlags:project.projectConfig.linkerFlags];
    }
    else
    {
        [driverFlags addObjectsFromArray:project.projectConfig.compilerFlags];
        return [self engineWithClangFlags:driverFlags withOtherLinkerFlags:project.projectConfig.linkerFlags];
    }
}

@end
