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

@interface LDEDiagnostic : NSObject

@property (nonatomic, readonly) CCDiagnosticType type;
@property (nonatomic, readonly) CCDiagnosticLevel level;
@property (nonatomic, readonly, copy) NSURL *fileURL;
@property (nonatomic, readonly) CCSourceLocation location;
@property (nonatomic, readonly, copy) NSString *message;

+ (instancetype)diagnosticWithType:(CCDiagnosticType)type level:(CCDiagnosticLevel)level fileURL:(NSURL *)fileURL location:(CCSourceLocation)location message:(NSString *)message;
+ (instancetype)diagnosticWithCCDiagnostic:(CCDiagnosticRef)ref;

+ (NSArray<LDEDiagnostic *> *)diagnosticsOfClangErrorWithString:(NSString *)errorString;
+ (void)diagnosticsOfClangErrorWithString:(NSString *)errorString usingArray:(NSMutableArray<LDEDiagnostic *> **)issues;

@end

#endif /* LDEDIAGNOSTIC_H */
