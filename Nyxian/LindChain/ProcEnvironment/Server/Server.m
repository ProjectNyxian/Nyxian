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

#import <LindChain/ProcEnvironment/Server/Server.h>
#import <LindChain/ProcEnvironment/Server/ServerSession.h>
#import <LindChain/ProcEnvironment/Surface/surface.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <os/lock.h>

@implementation Server {
    os_unfair_lock _lock;
    NSMutableSet<xpc_endpoint_t> *_canConnectTable;
}

- (instancetype)init
{
    self = [super init];
    _canConnectTable = [[NSMutableSet alloc] init];
    _lock = OS_UNFAIR_LOCK_INIT;
    return self;
}

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
{
    if(![self endpointUnregisterAndValidate:[listener.endpoint _endpoint]])
    {
        return NO;
    }
    
    /*
     * setting connection to the host up.
     *
     * note: this is a very early API still from the
     *       Nyxian 0.7.x days, we are heading deprecation
     *       of this API. so please do not add new features
     *       to this API, we are not microsoft and we will
     *       not support 20 APIs at the same time which
     *       do the exact same thing.
     */
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(ServerProtocol)];
    ServerSession *serverSession = [[ServerSession alloc] initWithProcessidentifier:newConnection.processIdentifier];
    newConnection.exportedObject = serverSession;
    [newConnection resume];
    
    return YES;
}

- (BOOL)endpointUnregisterAndValidate:(xpc_endpoint_t)endpoint
{
    os_unfair_lock_lock(&_lock);
    
    for(xpc_endpoint_t allowedEndpoint in _canConnectTable)
    {
        if(xpc_equal(allowedEndpoint, endpoint))
        {
            [_canConnectTable removeObject:allowedEndpoint];
            os_unfair_lock_unlock(&_lock);
            return true;
        }
    }

    os_unfair_lock_unlock(&_lock);
    return false;
}

- (NSXPCListener*)getTicketListener
{
    NSXPCListener *listener = [NSXPCListener anonymousListener];
    listener.delegate = self;
    [listener resume];
    
    os_unfair_lock_lock(&_lock);
    [_canConnectTable addObject:[listener.endpoint _endpoint]];
    os_unfair_lock_unlock(&_lock);
    
    return listener;
}

+ (NSXPCListenerEndpoint*)getTicket
{
    static Server *serverSingleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        serverSingleton = [[Server alloc] init];
    });
    NSXPCListener *listener = [serverSingleton getTicketListener];
    return listener.endpoint;
}

@end
