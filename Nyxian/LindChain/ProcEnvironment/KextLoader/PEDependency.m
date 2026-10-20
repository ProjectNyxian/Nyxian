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

#import <LindChain/ProcEnvironment/KextLoader/PEDependency.h>

@implementation PEDependency

+ (instancetype)dependencyForString:(NSString*)depString
{
    NSError *error = nil;
    NSString *pattern = @"^([^<]+)<min:([^,]+),max:([^>]+)>$";
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:&error];
    NSTextCheckingResult *match = [regex firstMatchInString:depString options:0 range:NSMakeRange(0, depString.length)];
    if(match && match.numberOfRanges == 4)
    {
        PEDependency *dep = [[PEDependency alloc] init];
        dep.bundleID = [depString substringWithRange:[match rangeAtIndex:1]];
        dep.minVersion = [depString substringWithRange:[match rangeAtIndex:2]];
        dep.maxVersion = [depString substringWithRange:[match rangeAtIndex:3]];
        return dep;
    }
    
    return nil;
}

@end
