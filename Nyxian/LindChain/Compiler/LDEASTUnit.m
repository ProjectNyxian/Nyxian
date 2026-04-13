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

#import <LindChain/Compiler/LDEASTUnit.h>
#include <objc/runtime.h>

@implementation LDEASTUnit

@dynamic file;

+ (void)load
{
    _CFRuntimeBridgeClasses(CCASTUnitGetTypeID(), "LDEASTUnit");
}

- (LDEFile*)file
{
    return (__bridge LDEFile*)CCASTUnitGetFile((__bridge void *)self);
}

- (NSArray<LDEDiagnostic*>*)diagnostics
{
    return (__bridge_transfer NSArray<LDEDiagnostic*>*)CCASTUnitCopyDiagnostics((__bridge void *)self);
}

- (BOOL)hasErrorOccured
{
    return CCASTUnitErrorOccured((__bridge void *)self);
}

@end

@implementation LDEMutableASTUnit

@dynamic file;

+ (instancetype)unit
{
    LDEASTUnit *obj = (__bridge_transfer LDEASTUnit*)CCASTUnitCreateMutable(kCFAllocatorDefault);
    object_setClass(obj, [LDEMutableASTUnit class]);
    return (LDEMutableASTUnit *)obj;
}

- (void)setFile:(LDEFile*)file
{
    CCASTUnitSetFile((__bridge void *)self, (__bridge CCFileRef)file);
}

- (BOOL)reparse
{
    return CCASTUnitReparse((__bridge void *)self);
}

- (void)setArguments:(NSArray<NSString*>*)arguments
{
    CCASTUnitSetArguments((__bridge void *)self, (__bridge CFArrayRef)arguments);
}

@end
