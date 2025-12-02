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

#import <ServiceKit/Service.h>
#include <dlfcn.h>

static ServiceServer *singletonServiceServer = nil;

@implementation ServiceServer

- (instancetype)initWithClass:(Class)instanceClass
           withServerProtocol:(Protocol *)serverProtocol
         withObserverProtocol:(Protocol *)observerProtocol
{
    self = [super init];
    
    _serverProtocol = serverProtocol;
    _observerProtocol = observerProtocol;
    _instanceClass = instanceClass;
    _listener = [[NSXPCListener alloc] init];
    _clients = [[NSMutableArray alloc] init];
    _instance = [[_instanceClass alloc] init];
    
    singletonServiceServer = self;
    
    return self;
}

+ (instancetype)sharedService
{
    return singletonServiceServer;
}

- (BOOL)listener:(NSXPCListener *)listener shouldAcceptNewConnection:(NSXPCConnection *)newConnection
{
    newConnection.exportedInterface = [NSXPCInterface interfaceWithProtocol:_serverProtocol];
    newConnection.exportedObject = _instance;
    newConnection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:_observerProtocol];
    [self.clients addObject:newConnection];
    [newConnection resume];
    [_instance clientDidConnectWithConnection:newConnection];
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

int LDEServiceMain(int argc,
                   char *argv[],
                   Class<LDEServiceProtocol> serviceClass)
{
    NSString *serviceIdentifier = [serviceClass servcieIdentifier];
    Protocol *serviceProtocol = [serviceClass serviceProtocol];
    Protocol *clientProtocol = [serviceClass observerProtocol];
    
    if(serviceIdentifier != nil &&
       serviceProtocol != nil)
    {
        ServiceServer *serviceServer = [[ServiceServer alloc] initWithClass:serviceClass withServerProtocol:serviceProtocol withObserverProtocol:clientProtocol];
        void (*environment_proxy_set_endpoint_for_service_identifier)(NSXPCListenerEndpoint *endpoint, NSString *serviceIdentifier) = dlsym(RTLD_DEFAULT, "environment_proxy_set_endpoint_for_service_identifier");
        environment_proxy_set_endpoint_for_service_identifier([serviceServer getEndpointForConnection], serviceIdentifier);
        CFRunLoopRun();
    }
    
    return 1;
}
