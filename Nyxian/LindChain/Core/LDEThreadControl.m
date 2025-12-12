/*
 Copyright (C) 2025 cr4zyengineer

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#import <LindChain/Core/LDEThreadControl.h>
#include <sys/sysctl.h>
#include <pthread.h>

static inline void *pthreadBlockTrampoline(void *ptr)
{
    void (^block)(void) = (__bridge_transfer void (^)(void))ptr;
    block();
    return NULL;
}

@interface LDEThreadControl ()

@property (nonatomic,strong,readonly) dispatch_semaphore_t semaphore;
@property (nonatomic,readonly) int threads;

@end

@implementation LDEThreadControl

- (instancetype)initWithThreads:(int)threads
{
    self = [super init];
    _semaphore = dispatch_semaphore_create(threads);
    _threads = threads;
    return self;
}

- (instancetype)init
{
    return [self initWithThreads:[LDEThreadControl getOptimalThreadCount]];
}

+ (int)getOptimalThreadCount
{
    static int cpuCount = 0;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        size_t size = sizeof(int);
        int result = sysctlbyname("hw.logicalcpu_max", &cpuCount, &size, NULL, 0);
        cpuCount = (result == 0 && cpuCount > 0) ? cpuCount : (int)[[NSProcessInfo processInfo] activeProcessorCount];
    });
    return cpuCount;
}

+ (int)getUserSetThreadCount
{
    NSNumber *value = [[NSUserDefaults standardUserDefaults] objectForKey:@"cputhreads"];
    int userSelected = (value && [value isKindOfClass:[NSNumber class]]) ? value.intValue : [self getOptimalThreadCount];
    return (userSelected == 0) ? 1 : userSelected;
}

+ (void)pthreadDispatch:(void (^)(void))code
{
    pthread_t thread;
    void *blockPointer = (__bridge_retained void *)code;
    pthread_create(&thread, NULL, pthreadBlockTrampoline, blockPointer);
    pthread_detach(thread);
}

- (void)dispatchExecution:(void (^)(void))code
           withCompletion:(void (^)(void))completion
{
    if(_lockdown)
    {
        completion();
        return;
    }
    
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    
    if(_lockdown)
    {
        completion();
        dispatch_semaphore_signal(self.semaphore);
        return;
    }
    
    [LDEThreadControl pthreadDispatch:^{
        code();
        completion();
        dispatch_semaphore_signal(self.semaphore);
    }];
}

@end
