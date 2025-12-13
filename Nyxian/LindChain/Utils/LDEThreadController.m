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

#import <LindChain/Utils/LDEThreadController.h>
#include <sys/sysctl.h>
#include <mach/mach.h>
#include <pthread.h>
#include <stdatomic.h>

static inline void *pthreadBlockTrampoline(void *ptr)
{
    void (^block)(void) = (__bridge_transfer void (^)(void))ptr;
    block();
    return NULL;
}

void LDEPthreadDispatch(void (^code)(void))
{
    pthread_t thread;
    void *blockPointer = (__bridge_retained void *)code;
    pthread_create(&thread, NULL, pthreadBlockTrampoline, blockPointer);
    pthread_detach(thread);
}

int LDEGetOptimalThreadCount(void)
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

int LDEGetUserSetThreadCount(void)
{
    NSNumber *value = [[NSUserDefaults standardUserDefaults] objectForKey:@"cputhreads"];
    int userSelected = (value && [value isKindOfClass:[NSNumber class]]) ? value.intValue : LDEGetOptimalThreadCount();
    return (userSelected == 0) ? 1 : userSelected;
}

static void *LDEWorkerThreadMain(void *arg)
{
    /* getting thread worker */
    LDEWorkerThread *worker = (LDEWorkerThread *)arg;
    
    /* pin current thread to a certain groups of CPUs */
    thread_affinity_policy_data_t policy = { .affinity_tag = worker->cpuIndex + 1 };
    thread_policy_set(pthread_mach_thread_np(pthread_self()), THREAD_AFFINITY_POLICY, (thread_policy_t)&policy, THREAD_AFFINITY_POLICY_COUNT);
    
    /* execution flow loop, gives me mach syscall server vibes ^^ */
    while(!atomic_load(&worker->shouldExit))
    {
        pthread_mutex_lock(&worker->mutex);
        
        /* waiting on work */
        while(!atomic_load(&worker->hasWork) && !atomic_load(&worker->shouldExit))
        {
            pthread_cond_wait(&worker->cond, &worker->mutex);
        }
        
        /* checking if we shall exit */
        if(atomic_load(&worker->shouldExit))
        {
            pthread_mutex_unlock(&worker->mutex);
            break;
        }
        
        /* setting blocks up  */
        void (^code)(void) = worker->currentBlock;
        void (^completion)(void) = worker->completionBlock;
        dispatch_semaphore_t sem = worker->semaphore;
        
        /* clear worker references to allow ARC to release captured objects */
        worker->currentBlock = nil;
        worker->completionBlock = nil;
        worker->semaphore = nil;
        
        /* storing that we are working on API request rawrrr x3 */
        atomic_store(&worker->hasWork, false);
        
        pthread_mutex_unlock(&worker->mutex);
        
        /* checking if there is code to execute */
        if(code)
        {
            code();
        }
        if(completion)
        {
            completion();
        }
        if(sem)
        {
            /* signaling semaphore ofc */
            dispatch_semaphore_signal(sem);
        }
    }
    
    return NULL;
}

@interface LDEThreadController ()

@property (nonatomic, strong, readonly) dispatch_semaphore_t semaphore;
@property (nonatomic, readonly) int threads;
@property (nonatomic, assign) LDEWorkerThread *workers;
@property (nonatomic, assign) int workerCount;
@property (nonatomic, assign) _Atomic(int) nextWorker;

@end

@implementation LDEThreadController

- (instancetype)initWithThreads:(uint32_t)threads
{
    self = [super init];
    _threads = (threads == 0) ? 1 : threads;
    _semaphore = dispatch_semaphore_create(threads);
    _workerCount = threads;
    _workers = calloc(threads, sizeof(LDEWorkerThread));
    atomic_init(&_nextWorker, 0);
    for(int i = 0; i < threads; i++)
    {
        _workers[i].cpuIndex = i % LDEGetOptimalThreadCount();
        _workers[i].shouldExit = false;
        _workers[i].hasWork = false;
        pthread_mutex_init(&_workers[i].mutex, NULL);
        pthread_cond_init(&_workers[i].cond, NULL);
        pthread_create(&_workers[i].thread, NULL, LDEWorkerThreadMain, &_workers[i]);
    }
    return self;
}

- (instancetype)init
{
    return [self initWithThreads:LDEGetOptimalThreadCount()];
}

- (instancetype)initWithUsersetThreadCount
{
    return [self initWithThreads:LDEGetUserSetThreadCount()];
}

- (void)dispatchExecution:(void (^)(void))code
           withCompletion:(void (^)(void))completion
{
    if(code == NULL ||
       _lockdown)
    {
        if(completion) completion();
        return;
    }
    
    dispatch_semaphore_wait(self.semaphore, DISPATCH_TIME_FOREVER);
    
    if(_lockdown)
    {
        if(completion) completion();
        dispatch_semaphore_signal(self.semaphore);
        return;
    }
    
    int workerIndex = atomic_fetch_add(&_nextWorker, 1) % _workerCount;
    LDEWorkerThread *worker = &_workers[workerIndex];
    pthread_mutex_lock(&worker->mutex);
    worker->currentBlock = code;
    worker->completionBlock = completion;
    worker->semaphore = self.semaphore;
    atomic_store(&worker->hasWork, true);
    pthread_cond_signal(&worker->cond);
    pthread_mutex_unlock(&worker->mutex);
}

- (void)dealloc
{
    for(int i = 0; i < _workerCount; i++)
    {
        pthread_mutex_lock(&_workers[i].mutex);
        atomic_store(&_workers[i].shouldExit, true);
        pthread_cond_signal(&_workers[i].cond);
        pthread_mutex_unlock(&_workers[i].mutex);
    }
    for(int i = 0; i < _workerCount; i++)
    {
        pthread_join(_workers[i].thread, NULL);
        pthread_mutex_destroy(&_workers[i].mutex);
        pthread_cond_destroy(&_workers[i].cond);
    }
    free(_workers);
}

@end
