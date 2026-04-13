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

#ifndef LDEASTUNIT_H
#define LDEASTUNIT_H

#import <LindChain/Compiler/LDECFType.h>
#import <LindChain/CoreCompiler/CCASTUnit.h>
#import <LindChain/Compiler/LDEDiagnostic.h>
#import <LindChain/Compiler/LDEFile.h>
#import <LindChain/Compiler/LDEFileSourceLocation.h>

@interface LDEASTUnit : LDECFType

@property (nonatomic, readonly) LDEFile *file;
@property (nonatomic, readonly) NSArray<LDEDiagnostic*> *diagnostics;
@property (nonatomic, readonly) BOOL hasErrorOccured;

- (LDEFileSourceLocation*)fileSourceLocationForDefinitionAtLocation:(CCSourceLocation)location;

@end

@interface LDEMutableASTUnit : LDEASTUnit

@property (nonatomic, readwrite) LDEFile *file;

+ (instancetype)unit;

- (BOOL)reparse;
- (void)setArguments:(NSArray<NSString*>*)arguments;

@end

#endif /* LDEASTUNIT_H */
