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

#import <CoreCompiler/CCKDiagnostic.h>

@implementation CCKDiagnostic

+ (void)load
{
    _CFRuntimeBridgeClasses(CCDiagnosticGetTypeID(), "CCKDiagnostic");
}

+ (instancetype)diagnosticWithType:(CCDiagnosticType)type
                             level:(CCDiagnosticLevel)level
                fileSourceLocation:(CCKFileSourceLocation *)fileSourceLocation
                           message:(NSString *)message
{
    /* FIXME: will crash without message */
    return (__bridge_transfer CCKDiagnostic*)CCDiagnosticCreate(kCFAllocatorSystemDefault, type, level, (__bridge CCFileSourceLocationRef)fileSourceLocation, (__bridge CFStringRef)message);
}

- (CCDiagnosticType)type
{
    return CCDiagnosticGetType((__bridge void *)self);
}

- (CCDiagnosticLevel)level
{
    return CCDiagnosticGetLevel((__bridge void *)self);
}

- (CCKFileSourceLocation*)fileSourceLocation
{
    return (__bridge CCKFileSourceLocation*)CCDiagnosticGetFileSourceLocation((__bridge void *)self);
}

- (NSString*)message
{
    return (__bridge NSString*)CCDiagnosticGetMessage((__bridge void *)self);
}

@end
