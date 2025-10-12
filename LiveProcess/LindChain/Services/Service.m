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

#import <LindChain/Services/Service.h>

static ServiceServer *singletonServiceServer = nil;

@implementation ServiceServer

- (instancetype)initWithClass:(Class)instanceClass
                 withProtocol:(Protocol *)instanceProtocol
{
    self = [super init];
    
    _protocol = instanceProtocol;
    _instanceClass = instanceClass;
    _listener = [[NSXPCListener alloc] init];
    
    
    singletonServiceServer = self;
    
    return self;
}

+ (instancetype)serverWithClass:(Class)instanceClass
                   withProtocol:(Protocol *)instanceProtocol
{
    return [[ServiceServer alloc] initWithClass:instanceClass
                                   withProtocol:instanceProtocol];
}

+ (instancetype)sharedService
{
    return singletonServiceServer;
}

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
{
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:_protocol];
    newConnection.exportedObject = [[_instanceClass alloc] init];;
    [newConnection resume];
    return YES;
}

- (NSXPCListenerEndpoint*)getEndpointForConnection
{
    dispatch_once(&_anonymousCraftOnce, ^{
        _listener = [NSXPCListener anonymousListener];
        _listener.delegate = self;
        [_listener resume];
    });
    return _listener.endpoint;
}

@end
