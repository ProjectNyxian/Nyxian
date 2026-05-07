/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 mach-port-t

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#import <LindChain/ProcEnvironment/syscall.h>
#import <LindChain/ServiceKit/Service.h>
#include <dlfcn.h>
#include <mach/mach.h>

@interface NSXPCListenerEndpoint ()

@property(nonatomic, setter=_setEndpoint:) xpc_object_t _endpoint;

@end

extern mach_port_t xpc_endpoint_copy_listener_port_4sim(NSObject<OS_xpc_object>*);

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

int PEServiceMain(int argc,
                  char *argv[],
                  Class<PEServiceProtocol> serviceClass)
{
    NSString *serviceIdentifier = [serviceClass servcieIdentifier];
    Protocol *serviceProtocol = [serviceClass serviceProtocol];
    Protocol *clientProtocol = [serviceClass observerProtocol];
    
    if(serviceIdentifier != nil &&
       serviceProtocol != nil)
    {
        ServiceServer *serviceServer = [[ServiceServer alloc] initWithClass:serviceClass withServerProtocol:serviceProtocol withObserverProtocol:clientProtocol];
        
        NSXPCListenerEndpoint *endpoint = [serviceServer getEndpointForConnection];
        mach_port_t port = xpc_endpoint_copy_listener_port_4sim(endpoint._endpoint);
        
        kern_return_t kr = mach_port_mod_refs(mach_task_self(), port, MACH_PORT_RIGHT_SEND, 1);
        if(kr != KERN_SUCCESS)
        {
            return -1;
        }
        
        if(port != MACH_PORT_NULL)
        {
            environment_syscall(SYS_pectl, PECTL_LS_SET_ENDPOINT, [serviceIdentifier UTF8String], port);
        }
        CFRunLoopRun();
    }
    
    return 1;
}
