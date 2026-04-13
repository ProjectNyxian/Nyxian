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
