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

#import <LindChain/ProcEnvironment/Server/Server.h>
#import <LindChain/ProcEnvironment/Server/ServerSession.h>
#import <LindChain/ProcEnvironment/Surface/surface.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>

@interface NSXPCListenerEndpoint ()

- (NSObject<OS_xpc_object>*)_endpoint;

@end

@implementation Server

- (instancetype)init
{
    self = [super init];
    _canConnectTable = [[NSMutableSet alloc] init];
    return self;
}

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
{
    // Checking if valid, if valid remove from list
    if(![self endpointUnregisterAndValidate:[listener.endpoint _endpoint]]) return NO;
    
    // Setting protocol interface
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:@protocol(ServerProtocol)];
    
    // Setting up server session
    ServerSession *serverSession = [[ServerSession alloc] initWithProcessidentifier:newConnection.processIdentifier];
    
    // Set exported object to the created server session
    newConnection.exportedObject = serverSession;
    
    // Resume connection
    [newConnection resume];
    
    return YES;
}

- (BOOL)endpointUnregisterAndValidate:(xpc_endpoint_t)endpoint
{
    xpc_endpoint_t catchedEndpoint = nil;
    for(xpc_endpoint_t allowedEndpoint in _canConnectTable)
    {
        if(xpc_equal(allowedEndpoint, endpoint))
        {
            catchedEndpoint = allowedEndpoint;
            break;
        }
    }
    
    if(catchedEndpoint != nil)
    {
        [_canConnectTable removeObject:catchedEndpoint];
        return YES;
    }

    return NO;
}

- (NSXPCListener*)getTicketListener
{
    NSXPCListener *listener = [NSXPCListener anonymousListener];
    listener.delegate = self;
    [listener resume];
    [_canConnectTable addObject:[listener.endpoint _endpoint]];
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
