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

#import <LindChain/Project/NXUtils.h>

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
