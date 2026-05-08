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

#ifndef MDKDIAGNOSTIC_H
#define MDKDIAGNOSTIC_H

#import <Foundation/Foundation.h>
#import <CoreCompiler/CCDiagnostic.h>
#import <MobileDevelopmentKit/MDKCFType.h>
#import <MobileDevelopmentKit/MDKFileSourceLocation.h>

@interface MDKDiagnostic : MDKCFType

@property (nonatomic, readonly) CCDiagnosticType type;
@property (nonatomic, readonly) CCDiagnosticLevel level;
@property (nonatomic, readonly) NSString *mainSource;
@property (nonatomic, readonly) MDKFileSourceLocation *fileSourceLocation;
@property (nonatomic, readonly) NSString *message;

+ (instancetype)diagnosticWithType:(CCDiagnosticType)type level:(CCDiagnosticLevel)level mainSource:(NSString*)mainSource fileSourceLocation:(MDKFileSourceLocation *)fileSourceLocation message:(NSString*)message;

@end

#endif /* MDKDIAGNOSTIC_H */
