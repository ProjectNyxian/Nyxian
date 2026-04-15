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

#ifndef LDEDIAGNOSTIC_H
#define LDEDIAGNOSTIC_H

#import <Foundation/Foundation.h>
#import <LindChain/CoreCompiler/CCDiagnostic.h>
#import <LindChain/Compiler/LDECFType.h>
#import <LindChain/Compiler/LDEFileSourceLocation.h>

@interface LDEDiagnostic : LDECFType

@property (nonatomic, readonly) CCDiagnosticType type;
@property (nonatomic, readonly) CCDiagnosticLevel level;
@property (nonatomic, readonly) LDEFileSourceLocation *fileSourceLocation;
@property (nonatomic, readonly) NSString *message;

+ (instancetype)diagnosticWithType:(CCDiagnosticType)type level:(CCDiagnosticLevel)level fileSourceLocation:(LDEFileSourceLocation *)fileSourceLocation message:(NSString *)message;

@end

#endif /* LDEDIAGNOSTIC_H */
