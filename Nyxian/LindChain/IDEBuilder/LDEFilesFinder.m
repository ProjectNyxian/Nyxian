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

#import <LindChain/IDEBuilder/LDEFilesFinder.h>

static BOOL LDEPathIsIgnored(NSString *relativePath,
                             NSSet<NSString *> *ignorePaths)
{
    for(NSString *ignore in ignorePaths)
    {
        if([relativePath isEqualToString:ignore])
        {
            return YES;
        }
        NSString *prefix = [ignore hasSuffix:@"/"] ? ignore : [ignore stringByAppendingString:@"/"];
        if([relativePath hasPrefix:prefix])
        {
            return YES;
        }
    }
    return NO;
}

NSArray<NSString*> *LDEFilesFinder(NSString *searchPath,
                                   NSSet<NSString*> *searchExtensions,
                                   NSSet<NSString*> *ignorePaths)
{
    NSMutableArray *foundFiles = [[NSMutableArray alloc] init];
    
    NSError *error = nil;
    NSArray<NSString*> *subPaths = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:searchPath error:&error];
    if(error) return foundFiles;
    
    for(NSString *relativePath in subPaths)
    {
        NSString *fullPath = [searchPath stringByAppendingFormat:@"/%@", relativePath];
        
        BOOL isDir = NO;
        if([[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDir] &&
            !isDir  &&
            [searchExtensions containsObject: [relativePath pathExtension]] &&
            !LDEPathIsIgnored(relativePath, ignorePaths))
        {
            [foundFiles addObject:fullPath];
        }
    }
    
    return foundFiles;
}
