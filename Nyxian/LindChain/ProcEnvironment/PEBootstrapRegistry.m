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

#import <LindChain/ProcEnvironment/PEBootstrapRegistry.h>
#import <LindChain/ProcEnvironment/Server/Server.h>
#import <os/lock.h>

@interface PEBootstrapWaiter : NSObject
@property (nonatomic, copy)   void (^completion)(mach_port_name_t);
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, assign) BOOL fired;
@end
 
@implementation PEBootstrapWaiter
@end

@implementation PEBootstrapRegistry {
    os_unfair_lock _lock;
    NSMutableDictionary<NSString*, NSMutableArray<PEBootstrapWaiter*>*> *_waiters;
}

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        _registry = [[NSMutableDictionary alloc] init];
        _waiters = [[NSMutableDictionary alloc] init];
        if(_registry == nil || _waiters == nil)
        {
            return nil;
        }
        _lock = OS_UNFAIR_LOCK_INIT;
    }
    return self;
}

+ (instancetype)shared
{
    static PEBootstrapRegistry *registrySingleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        registrySingleton = [[PEBootstrapRegistry alloc] init];
    });
    return registrySingleton;
}

- (NSXPCListenerEndpoint*)getEndpointWithServiceIdentifier:(NSString*)serviceIdentifier
{
    mach_port_name_t port = [self getMachPortNameWithServiceIdentifier:serviceIdentifier];
    if(port == MACH_PORT_NULL)
    {
        return nil;
    }
    
    NSXPCListenerEndpoint *endpoint = [[NSXPCListenerEndpoint alloc] init];
    endpoint._endpoint = xpc_endpoint_create_mach_port_4sim(port);
    if(endpoint == nil || endpoint._endpoint == nil)
    {
        return nil;
    }
    
    return endpoint;
}

- (mach_port_name_t)getMachPortNameWithServiceIdentifier:(NSString*)serviceIdentifier
{
    os_unfair_lock_lock(&_lock);
    NSNumber *number = _registry[serviceIdentifier];
    os_unfair_lock_unlock(&_lock);
    return [number unsignedIntValue];
}

- (void)setMachPortName:(mach_port_name_t)port
   forServiceIdentifier:(NSString*)serviceIdentifier
{
    os_unfair_lock_lock(&_lock);
    NSNumber *previousPort = _registry[serviceIdentifier];
    if(previousPort != nil)
    {
        mach_port_deallocate(mach_task_self(), [previousPort unsignedIntValue]);
    }
    _registry[serviceIdentifier] = [NSNumber numberWithUnsignedInt:port];
    
    NSArray<PEBootstrapWaiter*> *pending = nil;
    NSMutableArray<PEBootstrapWaiter*> *list = _waiters[serviceIdentifier];
    if(list.count > 0)
    {
        pending = [list copy];
        for(PEBootstrapWaiter *waiter in pending)
        {
            waiter.fired = YES;
        }
        [_waiters removeObjectForKey:serviceIdentifier];
    }
    
    os_unfair_lock_unlock(&_lock);
    
    for(PEBootstrapWaiter *waiter in pending)
    {
        void (^completion)(mach_port_name_t) = waiter.completion;
        dispatch_async(waiter.queue, ^{
            completion(port);
        });
    }
}

- (void)waitForServiceIdentifier:(NSString*)serviceIdentifier
                         timeout:(NSTimeInterval)timeout
                           queue:(dispatch_queue_t)queue
                      completion:(void (^)(mach_port_name_t))completion
{
    if(serviceIdentifier.length == 0 || completion == nil)
    {
        return;
    }
    
    dispatch_queue_t target = queue ?: dispatch_get_main_queue();
    
    os_unfair_lock_lock(&_lock);
    NSNumber *existing = _registry[serviceIdentifier];
    if(existing != nil)
    {
        os_unfair_lock_unlock(&_lock);
        mach_port_name_t port = (mach_port_name_t)existing.unsignedIntValue;
        dispatch_async(target, ^{ completion(port); });
        return;
    }
    
    PEBootstrapWaiter *waiter = [[PEBootstrapWaiter alloc] init];
    waiter.completion = completion;
    waiter.queue = target;
    waiter.fired = NO;
    
    NSMutableArray<PEBootstrapWaiter*> *list = _waiters[serviceIdentifier];
    if(list == nil)
    {
        list = [NSMutableArray array];
        _waiters[serviceIdentifier] = list;
    }
    [list addObject:waiter];
    os_unfair_lock_unlock(&_lock);
    
    if(timeout > 0)
    {
        __weak typeof(self) weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(timeout * NSEC_PER_SEC)), dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
            [weakSelf _expireWaiter:waiter forServiceIdentifier:serviceIdentifier];
        });
    }
}
 
- (void)_expireWaiter:(PEBootstrapWaiter*)waiter
 forServiceIdentifier:(NSString*)serviceIdentifier
{
    os_unfair_lock_lock(&_lock);
    if(waiter.fired)
    {
        /* registration beat the timeout =3c */
        os_unfair_lock_unlock(&_lock);
        return;
    }
    waiter.fired = YES;
    
    NSMutableArray<PEBootstrapWaiter*> *list = _waiters[serviceIdentifier];
    [list removeObjectIdenticalTo:waiter];
    if(list.count == 0)
    {
        [_waiters removeObjectForKey:serviceIdentifier];
    }
    os_unfair_lock_unlock(&_lock);
    
    void (^completion)(mach_port_name_t) = waiter.completion;
    dispatch_async(waiter.queue, ^{ completion(MACH_PORT_NULL); });
}
 
- (mach_port_name_t)waitForMachPortNameWithServiceIdentifier:(NSString*)serviceIdentifier
                                                     timeout:(NSTimeInterval)timeout
{
    __block mach_port_name_t result = MACH_PORT_NULL;
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);
    
    [self waitForServiceIdentifier:serviceIdentifier timeout:timeout queue:dispatch_get_global_queue(QOS_CLASS_UTILITY, 0) completion:^(mach_port_name_t port) {
        result = port;
        dispatch_semaphore_signal(sem);
    }];
    
    dispatch_time_t deadline = (timeout > 0) ? dispatch_time(DISPATCH_TIME_NOW, (int64_t)((timeout + 1.0) * NSEC_PER_SEC)) : DISPATCH_TIME_FOREVER;
    if(dispatch_semaphore_wait(sem, deadline) != 0)
    {
        return MACH_PORT_NULL;
    }
    
    return result;
}

- (void)removeMachPortForServiceIdentifier:(NSString*)serviceIdentifier
{
    os_unfair_lock_lock(&_lock);
    NSNumber *number = _registry[serviceIdentifier];
    if(number == NULL)
    {
        os_unfair_lock_unlock(&_lock);
        return;
    }
    
    mach_port_name_t port = [number unsignedIntValue];
    mach_port_deallocate(mach_task_self(), port);
    [_registry removeObjectForKey:serviceIdentifier];
    os_unfair_lock_unlock(&_lock);
}

@end
