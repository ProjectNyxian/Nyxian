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

#ifndef MDKASTUNIT_H
#define MDKASTUNIT_H

#import <MobileDevelopmentKit/MDKCFType.h>
#import <MobileDevelopmentKit/MDKDiagnostic.h>
#import <MobileDevelopmentKit/MDKFile.h>
#import <MobileDevelopmentKit/MDKFileSourceLocation.h>
#import <CoreCompiler/CCASTUnit.h>

@interface MDKASTUnit : MDKCFType

@property (nonatomic, readonly) MDKFile *file;
@property (nonatomic, readonly) NSArray<MDKDiagnostic*> *diagnostics;
@property (nonatomic, readonly) BOOL hasErrorOccured;

- (MDKFileSourceLocation*)fileSourceLocationForDefinitionAtLocation:(CCSourceLocation)location;

@end

@interface MDKMutableASTUnit : MDKASTUnit

@property (nonatomic, readwrite) MDKFile *file;

+ (instancetype)unit;

- (BOOL)reparse;
- (void)setArguments:(NSArray<NSString*>*)arguments;

@end

#endif /* MDKASTUNIT_H */
