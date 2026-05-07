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

#ifndef CCKDRIVER_H
#define CCKDRIVER_H

#import <Foundation/Foundation.h>
#import <CoreCompiler/CCKDriver.h>
#import <CoreCompiler/CCKCFType.h>
#import <CoreCompiler/CCKJob.h>
#import <CoreCompiler/CCKFile.h>
#import <CoreCompiler/CCKSDK.h>

@class CCKDriver;

@protocol CCKDriverDelegate <NSObject>
@optional
- (NSString * _Nullable)driver:(CCKDriver * _Nonnull)driver outputPathForInputFile:(CCKFile * _Nonnull)file;
- (BOOL)driver:(CCKDriver * _Nonnull)driver skipCompileForInputFile:(CCKFile * _Nonnull)file;
@end

@interface CCKDriver : CCKCFType

@property (nonatomic, readonly, copy, nullable) NSURL *sysrootURL;
@property (nonatomic, readonly, copy, nullable) CCKSDK *sdk;

@property (nonatomic, readwrite, weak) id<CCKDriverDelegate> delegate;

+ (instancetype _Nullable)driverWithArguments:(NSArray<NSString*> * _Nonnull)arguments withType:(CCDriverType)type;
- (NSArray<CCKJob*> * _Nullable)generateJobs;

@end

#endif /* CCKDRIVER_H */
