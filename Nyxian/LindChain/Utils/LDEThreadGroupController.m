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

#import <LindChain/Utils/LDEThreadGroupController.h>

@interface LDEThreadGroupController ()

@property (nonatomic,strong) dispatch_group_t group;

@end

@implementation LDEThreadGroupController

- (instancetype)initWithThreads:(uint32_t)threads
{
    self = [super initWithThreads:threads];
    _group = dispatch_group_create();
    return self;
}

- (instancetype)init
{
    self = [super init];
    _group = dispatch_group_create();
    return self;
}

- (instancetype)initWithUsersetThreadCount
{
    self = [super initWithUsersetThreadCount];
    _group = dispatch_group_create();
    return self;
}

- (void)dispatchExecution:(void (^)(void))code
           withCompletion:(void (^)(void))completion
{
    /* entering group befaure dispatching the passed code */
    dispatch_group_enter(self.group);
    
    /* now execute ^^ */
    [super dispatchExecution:code withCompletion:^{
        /* checking and running completion if it exists */
        if(completion) completion();
        
        /* leaving entered group */
        dispatch_group_leave(self.group);
    }];
}

- (void)wait
{
    /* never timeout */
    dispatch_group_wait(_group, DISPATCH_TIME_FOREVER);
}

@end
