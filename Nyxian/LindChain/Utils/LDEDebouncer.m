/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2025 - 2026 emexlab

 This file is part of Nyxian.

 Licensed under the emexLabs Public Source License, version 1.1
 (EPSL 1.1).

 Private use and modification are permitted under the license.
 Redistribution of source or binaries, modified or unmodified,
 requires prior written permission from emexLabs.

 External deployment is subject to the source-availability
 requirements and other conditions of the license.

 Provided "AS IS", without warranty, to the extent permitted by law.

 See LICENSE for the full license terms.
*/

#import <LindChain/Utils/LDEDebouncer.h>

@interface LDEDebouncer ()

@property (atomic,strong,readwrite) dispatch_block_t block;
@property (atomic,strong,readonly) dispatch_queue_t queue;
@property (atomic,weak,readwrite) id target;
@property (atomic,assign,readwrite) SEL selector;

@end

@implementation LDEDebouncer

// MARK: Initilizer
- (instancetype)initWithDelay:(NSTimeInterval)delay
                    withQueue:(dispatch_queue_t)queue
{
    self = [super init];
    if(self)
    {
        _delay = delay;
        _queue = queue;
    }
    return self;
}

- (instancetype)initWithDelay:(NSTimeInterval)delay
                    withQueue:(dispatch_queue_t)queue
                   withTarget:(id)target
                 withSelector:(SEL)selector
{
    self = [self initWithDelay:delay withQueue:queue];
    if(self)
    {
        [self setTarget:target withSelector:selector];
    }
    return self;
}

// MARK: Functionality
- (void)setTarget:(id)target
     withSelector:(SEL)selector
{
    /* setting target and selector */
    self.target = target;
    self.selector = selector;
}

- (void)debounce
{
    /* cancel any pending block */
    [self invalidate];
    
    /* create a fresh block */
    __weak typeof(self) weakSelf = self;
    _block = dispatch_block_create(0, ^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        if(!strongSelf)
        {
            return;
        }
        
        __strong id target = strongSelf.target;
        if(!target || !strongSelf.selector)
        {
            return;
        }
        
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
        [target performSelector:strongSelf.selector];
#pragma clang diagnostic pop
    });
    
    /* schedule it */
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(self.delay * NSEC_PER_SEC)), self.queue, self.block);
}

- (void)invalidate
{
    /* cancel any pending block */
    if(self.block)
    {
        dispatch_block_cancel(self.block);
    }
}

@end
