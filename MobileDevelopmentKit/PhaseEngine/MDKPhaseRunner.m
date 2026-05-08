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

#import <MobileDevelopmentKit/MDKPhaseRunner.h>
#import <MobileDevelopmentKit/MDKThreadPoolGroup.h>
#import <CoreCompiler/CCUtils.h>

@implementation MDKPhaseRunner

+ (instancetype)runnerWithEngine:(MDKPhaseEngine*)engine
{
    return [[self alloc] initWithEngine:engine];
}

- (instancetype)initWithEngine:(MDKPhaseEngine*)engine
{
    self = [super init];
    if(self)
    {
        _engine = engine;
    }
    return self;
}

- (BOOL)runJob:(MDKJob*)job withinPhase:(MDKPhase*)phase
{
    NSArray<MDKDiagnostic*> *diagnostic = nil;
    NSString *mainSource = nil;
    BOOL success = [job executeJobWithOutDiagnostics:&diagnostic withOutMainSource:&mainSource];
    
    /*
     * when delegation is passed then we
     * gonna have to report those diagnostic's
     * if not we'll drop em.
     */
    if([_delegate respondsToSelector:@selector(runner:phase:finishedRunningJob:withResultingDiagnostics:withMainSource:wasSuccessful:)])
    {
        [_delegate runner:self phase:phase finishedRunningJob:job withResultingDiagnostics:diagnostic withMainSource:mainSource wasSuccessful:success];
    }
    
    return success;
}

- (BOOL)runPhase:(MDKPhase*)phase
{
    if(phase.isMultithreadingSupported)
    {
        /*
         * get the amount of threads wished to use
         * when executing this multithreaded operation
         * usually from the delegation, if not we fallback
         * to what LLVM says using the CoreCompiler utility
         * API.
         */
        CFIndex threadCount = 1;
        if([_delegate respondsToSelector:@selector(runner:multithreadingThreadCountForPhase:)])
        {
            threadCount = [_delegate runner:self multithreadingThreadCountForPhase:phase];
        }
        else
        {
            threadCount = CCGetMaximumPerformanceCores();
        }
        
        /*
         * the thread pool group is nice, because it schedules
         * and handles jobs with a round robin like threading
         * mechanism, but improved for CoreCompiler use.
         */
        MDKThreadPoolGroup *threadPoolGroup = [[MDKThreadPoolGroup alloc] initWithThreads:threadCount];
        if(threadPoolGroup == nil)
        {
            /*
             * in-case it fails which is very unlikely we fallback
             * to using non multithreaded approach.
             */
            goto fallback_no_multithreading;
        }
        
        NSArray<MDKJob*> *jobs = phase.jobs;
        
        /*
         * "registering" every job, thats basically every jobs
         * check-in.
         */
        CFIndex count = jobs.count;
        for(CFIndex i = 0; i < count; i++)
        {
            [threadPoolGroup enter];
        }
        
        /* finally running the jobs */
        for(MDKJob *job in jobs)
        {
            [threadPoolGroup dispatchExecution:^{
                if(![self runJob:job withinPhase:phase])
                {
                    threadPoolGroup.lockdown = YES;
                }
            } withCompletion:nil];
        }
        
        [threadPoolGroup wait];
        
        if(threadPoolGroup.lockdown)
        {
            return NO;
        }
    }
    else
fallback_no_multithreading:
    {
        NSArray<MDKJob*> *jobs = phase.jobs;
        
        /* finally running the jobs */
        for(MDKJob *job in jobs)
        {
            if(![self runJob:job withinPhase:phase])
            {
                return NO;
            }
        }
    }
    
    return YES;
}

- (BOOL)runPhasesWithPhases:(NSArray*)phases
{
    for(id rawPhase in phases)
    {
        if([rawPhase isKindOfClass:[MDKPhase class]])
        {
            MDKPhase *phase = rawPhase;
            if(![self runPhase:phase])
            {
                return NO;
            }
        }
        else if([rawPhase isKindOfClass:[MDKPhaseEngine class]])
        {
            MDKPhaseEngine *phaseEngine = rawPhase;
            NSArray<MDKPhase*> *phases = [phaseEngine generatePhases];
            
            if(phases == nil)
            {
                return NO;
            }
            
            if(![self runPhasesWithPhases:phases])
            {
                return NO;
            }
        }
    }
    
    return YES;
}

- (BOOL)runPhases
{
    NSArray<MDKPhase*> *phases = [_engine generatePhases];
    if(phases == nil)
    {
        return NO;
    }
    
    if(![self runPhasesWithPhases:phases])
    {
        return NO;
    }
    
    return YES;
}

@end
