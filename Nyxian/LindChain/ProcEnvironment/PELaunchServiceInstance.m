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

#import <LindChain/ProcEnvironment/PELaunchServiceInstance.h>
#import <LindChain/ProcEnvironment/PEProcessManager.h>
#import <LindChain/ProcEnvironment/PEBootstrapRegistry.h>
#import <os/lock.h>
#import <ksurface_config.h>

@implementation PELaunchServiceInstance {
    os_unfair_lock _lock;
    PEProcess *_process;
    pid_t _pid;
    PELaunchServiceInstanceState _state;
}

- (instancetype)initWithItems:(NSDictionary *)items
{
    self = [super init];
    if(self == nil)
    {
        return nil;
    }
    
    _uniqueBootstrapRegistryIdentifier = items[@"PEUBID"];
    _lock = OS_UNFAIR_LOCK_INIT;
    _items = [items copy];
    _pid = -1;
    _state = PELaunchServiceInstanceStateIdle;
    
    return self;
}

- (PEProcess *)process
{
    os_unfair_lock_lock(&_lock);
    PEProcess *process = _process;
    os_unfair_lock_unlock(&_lock);
    return process;
}

- (pid_t)processIdentifier
{
    os_unfair_lock_lock(&_lock);
    pid_t pid = _pid;
    os_unfair_lock_unlock(&_lock);
    return pid;
}

- (PELaunchServiceInstanceState)state
{
    os_unfair_lock_lock(&_lock);
    PELaunchServiceInstanceState state = _state;
    os_unfair_lock_unlock(&_lock);
    return state;
}

- (BOOL)isRunning
{
    return self.state == PELaunchServiceInstanceStateRunning;
}

- (BOOL)launch
{
    os_unfair_lock_lock(&_lock);
    if(_state != PELaunchServiceInstanceStateIdle)
    {
        os_unfair_lock_unlock(&_lock);
        return NO;
    }
    _state = PELaunchServiceInstanceStateLaunching;
    os_unfair_lock_unlock(&_lock);
    
    pid_t pid = [[PEProcessManager shared] spawnProcessWithItems:_items withKernelSurfaceProcess:kernel_proc_];
    if(pid < 0)
    {
        os_unfair_lock_lock(&_lock);
        _state = PELaunchServiceInstanceStateExited;
        os_unfair_lock_unlock(&_lock);
        return NO;
    }
    
    PEProcess *process = [[PEProcessManager shared] processForProcessIdentifier:pid];
    if(process == nil)
    {
        kill(pid, SIGKILL);
        os_unfair_lock_lock(&_lock);
        _state = PELaunchServiceInstanceStateExited;
        os_unfair_lock_unlock(&_lock);
        return NO;
    }
    
    os_unfair_lock_lock(&_lock);
    if(_state == PELaunchServiceInstanceStateTerminated)
    {
        os_unfair_lock_unlock(&_lock);
        [process sendSignal:SIGKILL];
        return NO;
    }
    _process = process;
    _pid = pid;
    _state = PELaunchServiceInstanceStateRunning;
    os_unfair_lock_unlock(&_lock);
    
    [process addObserver:self];
    
    return YES;
}

- (void)terminate
{
    os_unfair_lock_lock(&_lock);
    PELaunchServiceInstanceState previous = _state;
    PEProcess *process = _process;
    _state = PELaunchServiceInstanceStateTerminated;
    _process = nil;
    os_unfair_lock_unlock(&_lock);
    
    if(previous != PELaunchServiceInstanceStateRunning || process == nil)
    {
        return;
    }
    
    [process sendSignal:SIGKILL];
}

- (void)process:(PEProcess *)process didExitWithWait4Code:(int)code
{
    os_unfair_lock_lock(&_lock);
    if(_state != PELaunchServiceInstanceStateRunning)
    {
        os_unfair_lock_unlock(&_lock);
        id<PELaunchServiceInstanceDelegate> delegate = self.delegate;
        if([delegate respondsToSelector:@selector(instanceDidExit:withWaitCode:)])
        {
            [delegate instanceDidExit:self withWaitCode:code];
        }
        return;
    }
    _state = PELaunchServiceInstanceStateExited;
    PEProcess *exited = _process;
    _process = nil;
    os_unfair_lock_unlock(&_lock);
    
    [exited removeObserver:self];
    
    id<PELaunchServiceInstanceDelegate> delegate = self.delegate;
    if([delegate respondsToSelector:@selector(instanceDidExit:withWaitCode:)])
    {
        [delegate instanceDidExit:self withWaitCode:code];
    }
}

- (mach_port_name_t)getEndpoint
{
    return [[PEBootstrapRegistry shared] waitForMachPortNameWithServiceIdentifier:[self uniqueBootstrapRegistryIdentifier] timeout:2.0];
}

- (NSXPCListenerEndpoint*)xpcEndpoint
{
    mach_port_name_t name = [self getEndpoint];
    if(name == MACH_PORT_NULL)
    {
        return NULL;
    }
    return [[PEBootstrapRegistry shared] getEndpointWithServiceIdentifier:[self uniqueBootstrapRegistryIdentifier]];
}

- (void)dealloc
{
    [[PEBootstrapRegistry shared] removeMachPortForServiceIdentifier:[self uniqueBootstrapRegistryIdentifier]];
    [self terminate];
}

@end
