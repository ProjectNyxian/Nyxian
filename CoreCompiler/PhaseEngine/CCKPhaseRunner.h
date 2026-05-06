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

#ifndef CCKPHASERUNNER_H
#define CCKPHASERUNNER_H

#import <Foundation/Foundation.h>
#import <CoreCompiler/CCKPhaseEngine.h>

@class CCKPhaseRunner;

@protocol CCKPhaseRunnerDelegate <NSObject>

@optional
- (void)runner:(CCKPhaseRunner * _Nonnull)runner phase:(CCKPhase * _Nonnull)phase finishedRunningJob:(CCKJob * _Nonnull)job withResultingDiagnostics:(NSArray<CCKDiagnostic*> * _Nullable)diagnostics withMainSource:(NSString * _Nullable)mainSource wasSuccessful:(BOOL)success;
- (CFIndex)runner:(CCKPhaseRunner * _Nonnull)runner multithreadingThreadCountForPhase:(CCKPhase * _Nonnull)phase;

@end

@interface CCKPhaseRunner : NSObject

@property (nonatomic, readonly, strong, nonnull) CCKPhaseEngine *engine;
@property (nonatomic, readwrite, weak, nullable) id<CCKPhaseRunnerDelegate> delegate;

+ (instancetype _Nullable)runnerWithEngine:(CCKPhaseEngine * _Nonnull)engine;

- (instancetype _Nullable)initWithEngine:(CCKPhaseEngine * _Nonnull)engine;

- (BOOL)runJob:(CCKJob * _Nonnull)job withinPhase:(CCKPhase * _Nonnull)phase;
- (BOOL)runPhase:(CCKPhase * _Nonnull)phase;
- (BOOL)runPhasesWithPhases:(NSArray * _Nonnull)phases;
- (BOOL)runPhases;

@end

#endif /* CCKPHASERUNNER_H */
