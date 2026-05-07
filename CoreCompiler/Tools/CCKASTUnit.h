/*
 * MIT License
 *
 * Copyright (c) 2026 mach-port-t
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#ifndef CCKASTUNIT_H
#define CCKASTUNIT_H

#import <CoreCompiler/CCKCFType.h>
#import <CoreCompiler/CCASTUnit.h>
#import <CoreCompiler/CCKDiagnostic.h>
#import <CoreCompiler/CCKFile.h>
#import <CoreCompiler/CCKFileSourceLocation.h>

@interface CCKASTUnit : CCKCFType

@property (nonatomic, readonly) CCKFile *file;
@property (nonatomic, readonly) NSArray<CCKDiagnostic*> *diagnostics;
@property (nonatomic, readonly) BOOL hasErrorOccured;

- (CCKFileSourceLocation*)fileSourceLocationForDefinitionAtLocation:(CCSourceLocation)location;

@end

@interface CCKMutableASTUnit : CCKASTUnit

@property (nonatomic, readwrite) CCKFile *file;

+ (instancetype)unit;

- (BOOL)reparse;
- (void)setArguments:(NSArray<NSString*>*)arguments;

@end

#endif /* CCKASTUNIT_H */
