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

#import <LindChain/Compiler/LDEFile.h>
#include <objc/runtime.h>

@implementation LDEFile

@dynamic fileURL;
@dynamic unsavedData;

+ (void)load
{
    _CFRuntimeBridgeClasses(CCFileGetTypeID(), "LDEFile");
}

+ (instancetype)fileWithURL:(NSURL*)fileURL
{
    return (__bridge_transfer LDEFile*)CCFileCreate(kCFAllocatorDefault, (__bridge CFURLRef)fileURL);
}

- (NSURL*)fileURL
{
    return (__bridge NSURL*)CCFileGetFileURL((__bridge void *)self);
}

- (NSData*)unsavedData
{
    return (__bridge NSData*)CCFileGetUnsavedData((__bridge void *)self);
}

- (CCFileType)type
{
    return CCFileGetType((__bridge void *)self);
}

@end

@implementation LDEMutableFile

@dynamic fileURL;
@dynamic unsavedData;

+ (instancetype)fileWithURL:(NSURL*)fileURL
{
    LDEFile *obj = (__bridge_transfer LDEFile*)CCFileCreateMutable(kCFAllocatorDefault, (__bridge CFURLRef)fileURL);
    object_setClass(obj, [LDEMutableFile class]);
    return (LDEMutableFile *)obj;
}

+ (instancetype)fileWithURL:(NSURL*)fileURL
            withUnsavedData:(NSData*)unsavedData
{
    LDEFile *obj = (__bridge_transfer LDEFile*)CCFileCreateMutableWithUnsavedData(kCFAllocatorDefault, (__bridge CFURLRef)fileURL, (__bridge CFDataRef)unsavedData);
    object_setClass(obj, [LDEMutableFile class]);
    return (LDEMutableFile *)obj;
}

- (void)setFileURL:(NSURL*)fileURL
{
    CCFileSetFileURL((__bridge void *)self, (__bridge CFURLRef)fileURL);
}

- (void)setUnsavedData:(NSData*)unsavedData
{
    CCFileSetUnsavedData((__bridge void *)self, (__bridge CFDataRef)unsavedData);
}

@end
