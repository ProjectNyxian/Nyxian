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
    if(self.block)
    {
        dispatch_block_cancel(self.block);
    }
    
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

@end
