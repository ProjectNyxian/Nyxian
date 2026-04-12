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

#import <LindChain/Compiler/LDEDiagnostic.h>

@implementation LDEDiagnostic

+ (void)load
{
    _CFRuntimeBridgeClasses(CCDiagnosticGetTypeID(), "LDEDiagnostic");
}

+ (instancetype)diagnosticWithType:(CCDiagnosticType)type
                             level:(CCDiagnosticLevel)level
                           fileURL:(NSURL*)fileURL
                          location:(CCSourceLocation)location
                           message:(NSString*)message
{
    /* MARK: will crash without message */
    return (__bridge_transfer LDEDiagnostic*)CCDiagnosticCreate(kCFAllocatorDefault, type, level, fileURL  ? CFRetain((__bridge CFURLRef)fileURL) : NULL, location, message  ? CFRetain((__bridge CFStringRef)message)   : NULL);
}

+ (instancetype)diagnosticWithCCDiagnostic:(CCDiagnosticRef)ref
{
    return (__bridge LDEDiagnostic*)ref;
}

- (CCDiagnosticType)type
{
    return CCDiagnosticGetType((__bridge void *)self);
}

- (CCDiagnosticLevel)level
{
    return CCDiagnosticGetLevel((__bridge void *)self);
}

- (NSURL*)fileURL
{
    return (__bridge NSURL *)CCDiagnosticGetFileURL((__bridge void *)self);
}

- (CCSourceLocation)location
{
    return CCDiagnosticGetLocation((__bridge void *)self);
}

- (NSString*)message
{
    return (__bridge NSString*)CCDiagnosticGetMessage((__bridge void *)self);
}

+ (CCDiagnosticLevel)SynitemLevelOfClangLevel:(NSString *)levelStr
{
    levelStr = [levelStr stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
    if([levelStr hasPrefix:@"error"]) return CCDiagnosticLevelError;
    if([levelStr hasPrefix:@"fatal"]) return CCDiagnosticLevelFatal;
    if([levelStr hasPrefix:@"warning"]) return CCDiagnosticLevelError;
    if([levelStr hasPrefix:@"remark"]) return CCDiagnosticLevelRemark;
    return CCDiagnosticLevelNote;
}

+ (NSArray<LDEDiagnostic *> *)diagnosticsOfClangErrorWithString:(NSString *)errorString
{
    NSMutableArray<LDEDiagnostic *> *issues = [[NSMutableArray alloc] init];
    [self diagnosticsOfClangErrorWithString:errorString usingArray:&issues];
    return issues;
}

+ (void)diagnosticsOfClangErrorWithString:(NSString *)errorString
                               usingArray:(NSMutableArray<LDEDiagnostic *> **)issues
{
    NSArray *errorLines = [errorString componentsSeparatedByString:@"\n"];
    
    for(NSString *line in errorLines)
    {
        NSArray *errorComponents = [line componentsSeparatedByString:@":"];
        if(errorComponents.count < 4)
        {
            continue;
        }
        
        NSString *potentialLine = errorComponents[1];
        NSString *potentialCol = errorComponents.count >= 5 ? errorComponents[2] : nil;
        BOOL hasLine = [potentialLine rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]].location != NSNotFound;
        if(!hasLine)
        {
            continue;
        }
        
        BOOL hasCol = potentialCol && [potentialCol rangeOfCharacterFromSet:[NSCharacterSet decimalDigitCharacterSet]].location != NSNotFound;
        NSUInteger levelIdx = hasCol ? 3 : 2;
        if(errorComponents.count <= levelIdx + 1)
        {
            continue;
        }
        
        NSURL *fileURL = [NSURL fileURLWithPath:errorComponents[0]];
        
        NSUInteger msgStart = levelIdx + 1;
        NSString *message = [[errorComponents subarrayWithRange:NSMakeRange(msgStart, errorComponents.count - msgStart)] componentsJoinedByString:@":"];
        message = [message stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]];
        
        [*issues addObject:[LDEDiagnostic diagnosticWithType:CCDiagnosticTypeFile level:[LDEDiagnostic SynitemLevelOfClangLevel:errorComponents[levelIdx]] fileURL:fileURL location:CCSourceLocationMake([potentialLine integerValue], hasCol ? [potentialCol integerValue] : 0) message:message]];
    }
}

@end
