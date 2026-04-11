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

#ifndef SYNDIAG_H
#define SYNDIAG_H

#import <Foundation/Foundation.h>
#import <LindChain/CoreCompiler/CoreCompiler.h>

@interface Syndiag : NSObject

@property (nonatomic,readwrite) CCDiagnosticType type;
@property (nonatomic,readwrite) CCDiagnosticLevel level;

@property (nonatomic,strong) NSString *filepath;
@property (nonatomic,readwrite) UInt64 line;
@property (nonatomic,readwrite) UInt64 column;

@property (nonatomic,strong) NSString *message;

/* will later be deprecated because LDEObjectCompiler will use SynpushCore utilites, as CompilerInvocation and so on use the same underlying APIs as SynpushCore */
+ (CCDiagnosticLevel)SynitemLevelOfClangLevel:(NSString *)levelStr;
+ (NSArray<Syndiag*> *)OfClangErrorWithString:(NSString*)errorString;
+ (void)OfClangErrorWithString:(NSString*)errorString usingArray:(NSMutableArray<Syndiag*> **)issues;

@end

#endif /* SYNDIAG_H */
