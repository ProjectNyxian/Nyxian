/*
 * MIT License
 *
 * Copyright (c) 2024 light-tech
 * Copyright (c) 2026 cr4zyengineer
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

#ifndef CCKPHASE_H
#define CCKPHASE_H

#import <Foundation/Foundation.h>
#import <CoreCompiler/CCKJob.h>

@interface CCKPhase : NSObject

@property (nonatomic, readonly) CCJobType type;
@property (nonatomic, readonly) BOOL isMultithreadingSupported;
@property (nonatomic, readonly, nonnull) NSArray<CCKJob*> *jobs;

+ (instancetype _Nonnull)phaseWithJobs:(NSArray<CCKJob*> * _Nonnull)jobs withJobType:(CCJobType)type withMultithreadingSupport:(BOOL)isMultithreadingSupported;
- (instancetype _Nonnull)initWithJobs:(NSArray<CCKJob*> * _Nonnull)jobs withJobType:(CCJobType)type withMultithreadingSupport:(BOOL)isMultithreadingSupported;

@end

#endif /* CCKPHASE_H */
