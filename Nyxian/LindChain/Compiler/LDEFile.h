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

#ifndef LDEFILE_H
#define LDEFILE_H

#import <LindChain/Compiler/LDECFType.h>
#import <LindChain/CoreCompiler/CCFile.h>

/*
 CC_EXPORT CFTypeID CCFileGetTypeID(void);

 CC_EXPORT CCMutableFileRef CCFileCreateMutable(CFAllocatorRef allocator, CFURLRef fileURL);
 CC_EXPORT CCMutableFileRef CCFileCreateMutableWithUnsavedData(CFAllocatorRef allocator, CFURLRef fileURL, CFDataRef data);
 CC_EXPORT CCFileRef CCFileCreateCopy(CFAllocatorRef allocator, CCFileRef file);
 CC_EXPORT CCMutableFileRef CCFileCreateMutableCopy(CFAllocatorRef allocator, CCFileRef file);

 CC_EXPORT CFURLRef CCFileGetFileURL(CCFileRef file);
 CC_EXPORT CFDataRef CCFileGetUnsavedData(CCFileRef file);
 CC_EXPORT CFDataRef CCFileCopyUnsavedData(CCFileRef file);
 CC_EXPORT void CCFileSetFileURL(CCMutableFileRef mutableFile, CFURLRef fileURL);
 CC_EXPORT void CCFileSetUnsavedData(CCMutableFileRef mutableFile, CFDataRef data);
 */

@interface LDEFile : LDECFType

@property (nonatomic, readonly) NSURL *fileURL;
@property (nonatomic, readonly) NSData *unsavedData;

@end

@interface LDEMutableFile : LDEFile

@property (nonatomic, readwrite) NSURL *fileURL;
@property (nonatomic, readwrite) NSData *unsavedData;

+ (instancetype)mutableFileWithFileURL:(NSURL*)fileURL;
+ (instancetype)mutableFileWithFileURL:(NSURL*)fileURL withUnsavedData:(NSData*)unsavedData;

@end

#endif /* LDEFILE_H */
