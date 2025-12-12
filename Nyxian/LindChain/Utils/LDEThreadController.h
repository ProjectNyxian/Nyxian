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

#ifndef LDETHREADCONTROL_H
#define LDETHREADCONTROL_H

#import <Foundation/Foundation.h>

void LDEPthreadDispatch(void (^code)(void));
int LDEGetOptimalThreadCount(void);
int LDEGetUserSetThreadCount(void);

typedef struct {
    pthread_t thread;
    pthread_mutex_t mutex;
    pthread_cond_t cond;
    void (^currentBlock)(void);
    void (^completionBlock)(void);
    dispatch_semaphore_t semaphore;
    int cpuIndex;
    _Atomic(bool) shouldExit;
    _Atomic(bool) hasWork;
} LDEWorkerThread;

@interface LDEThreadController : NSObject

@property (atomic,readwrite) BOOL lockdown;

- (instancetype)initWithThreads:(uint32_t)threads;
- (instancetype)init;
- (instancetype)initWithUsersetThreadCount;

- (void)dispatchExecution:(void (^)(void))code withCompletion:(void (^)(void))completion;

@end

#endif /* LDETHREADCONTROL_H */
