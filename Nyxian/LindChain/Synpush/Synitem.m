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

#import <LindChain/Synpush/Synitem.h>

@implementation Synitem

+ (UInt8)SynitemLevelOfClangLevel:(NSString *)levelStr {
    levelStr = [levelStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if ([levelStr hasPrefix:@"error"] || [levelStr hasPrefix:@"fatal"]) return 2;
    if ([levelStr hasPrefix:@"warning"]) return 1;
    if ([levelStr hasPrefix:@"note"]) return 3;
    if ([levelStr hasPrefix:@"remark"]) return 4;
    return 0;
}

+ (NSArray<Synitem *> *)OfClangErrorWithString:(NSString *)errorString {
    NSMutableArray<Synitem *> *issues = [[NSMutableArray alloc] init];
    [self OfClangErrorWithString:errorString usingArray:&issues];
    return issues;
}

+ (void)OfClangErrorWithString:(NSString *)errorString
                    usingArray:(NSMutableArray<Synitem *> **)issues {
    NSArray *errorLines = [errorString componentsSeparatedByString:@"\n"];
    
    for (NSString *line in errorLines) {
        NSArray *errorComponents = [line componentsSeparatedByString:@":"];
        if (errorComponents.count < 4) continue;
        
        NSString *potentialLine = errorComponents[1];
        NSString *potentialCol = errorComponents.count >= 5 ? errorComponents[2] : nil;
        BOOL hasLine = [potentialLine rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]].location != NSNotFound;
        if (!hasLine) continue;
        
        BOOL hasCol = potentialCol && [potentialCol rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]].location != NSNotFound;
        NSUInteger levelIdx = hasCol ? 3 : 2;
        if (errorComponents.count <= levelIdx + 1) continue;
        
        Synitem *item = [[Synitem alloc] init];
        item.line = [potentialLine integerValue];
        item.column = hasCol ? [potentialCol integerValue] : 0;
        item.type = [Synitem SynitemLevelOfClangLevel:errorComponents[levelIdx]];
        
        if (item.type == 0) continue;
        
        NSUInteger msgStart = levelIdx + 1;
        item.message = [[errorComponents subarrayWithRange:NSMakeRange(msgStart, errorComponents.count - msgStart)] componentsJoinedByString:@":"];
        item.message = [item.message stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        [*issues addObject:item];
    }
}

@end
