/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 cr4zyengineer

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

#import <LindChain/Synpush/Syndiag.h>

@implementation Syndiag

+ (SPDiagLevel)SynitemLevelOfClangLevel:(NSString *)levelStr
{
    levelStr = [levelStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if([levelStr hasPrefix:@"error"]) return SPDiagLevelError;
    if([levelStr hasPrefix:@"fatal"]) return SPDiagLevelFatal;
    if([levelStr hasPrefix:@"warning"]) return SPDiagLevelWarning;
    if([levelStr hasPrefix:@"remark"]) return SPDiagLevelRemark;
    return SPDiagLevelNote;
}

+ (NSArray<Syndiag *> *)OfClangErrorWithString:(NSString *)errorString
{
    NSMutableArray<Syndiag *> *issues = [[NSMutableArray alloc] init];
    [self OfClangErrorWithString:errorString usingArray:&issues];
    return issues;
}

+ (void)OfClangErrorWithString:(NSString *)errorString
                    usingArray:(NSMutableArray<Syndiag *> **)issues
{
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
        
        Syndiag *syndiag = [[Syndiag alloc] init];
        syndiag.line = [potentialLine integerValue];
        syndiag.column = hasCol ? [potentialCol integerValue] : 0;
        syndiag.type = SPDiagTypeFile;
        syndiag.level = [Syndiag SynitemLevelOfClangLevel:errorComponents[levelIdx]];
        
        NSUInteger msgStart = levelIdx + 1;
        syndiag.message = [[errorComponents subarrayWithRange:NSMakeRange(msgStart, errorComponents.count - msgStart)] componentsJoinedByString:@":"];
        syndiag.message = [syndiag.message stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        [*issues addObject:syndiag];
    }
}

@end
