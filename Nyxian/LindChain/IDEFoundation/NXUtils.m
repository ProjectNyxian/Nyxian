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

#import <LindChain/IDEFoundation/NXUtils.h>

NSString *NXMakeContentCodeFriendly(NSString *content)
{
    return [[content componentsSeparatedByCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]] componentsJoinedByString:@"_"];
}

NSString *NXSubstituteContent(NSString *content,
                              NSDictionary<NSString *, NSString *> *variables,
                              BOOL makeCodeFriendly)
{
    static NSRegularExpression *regex;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        regex = [NSRegularExpression regularExpressionWithPattern:@"\\$\\(([A-Za-z_][A-Za-z0-9_]*)\\)" options:0 error:NULL];
    });

    NSMutableString *result = [NSMutableString string];
    __block NSUInteger cursor = 0;
    NSRange full = NSMakeRange(0, content.length);

    [regex enumerateMatchesInString:content options:0 range:full usingBlock:^(NSTextCheckingResult *m, NSMatchingFlags flags, BOOL *stop) {
        NSRange matchRange = m.range;
        [result appendString:[content substringWithRange:NSMakeRange(cursor, matchRange.location - cursor)]];

        NSString *key = [content substringWithRange:[m rangeAtIndex:1]];
        NSString *value = variables[key];
        if(value)
        {
            if(!makeCodeFriendly)
            {
                value = NXMakeContentCodeFriendly(value);
            }
            [result appendString:value];
        }
        else
        {
            [result appendString:[content substringWithRange:matchRange]];
        }

        cursor = matchRange.location + matchRange.length;
    }];

    [result appendString:[content substringWithRange:NSMakeRange(cursor, content.length - cursor)]];
    return result;
}

NSURL *NXExpectedObjectFileURLForFileURL(NSURL *fileURL)
{
    /* it can be this easy lol */
    return [fileURL URLByAppendingPathExtension:@"o"];
}

NSURL *NXRelativeURLFromBaseURLToFullURL(NSURL *baseURL,
                                         NSURL *fullURL)
{
    NSArray<NSString*> *baseComponents = [[baseURL standardizedURL] pathComponents];
    NSMutableArray<NSString*> *fullComponents = [[[fullURL standardizedURL] pathComponents] mutableCopy];
    
    [fullComponents removeObjectsInRange:NSMakeRange(0, [baseComponents count])];
    
    return [NSURL fileURLWithPath:[fullComponents componentsJoinedByString:@"/"]];
}
