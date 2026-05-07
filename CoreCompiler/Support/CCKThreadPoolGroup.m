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

#import <CoreCompiler/CCKThreadPoolGroup.h>

@implementation CCKThreadPoolGroup {
    dispatch_group_t _group;
}

- (instancetype)initWithThreads:(CFIndex)threads
{
    self = [super initWithThreads:threads];
    _group = dispatch_group_create();
    return self;
}

- (void)enter
{
    dispatch_group_enter(_group);
}

- (void)wait
{
    /* never timeout */
    dispatch_group_wait(_group, DISPATCH_TIME_FOREVER);
}

- (void)dispatchExecution:(void (^)(void))code
           withCompletion:(void (^)(void))completion
{
    /* now execute ^^ */
    [super dispatchExecution:code withCompletion:^{
        /* checking and running completion if it exists */
        if(completion) completion();
        
        /* leaving entered group */
        dispatch_group_leave(self->_group);
    }];
}

@end
