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

#import <LindChain/ProcEnvironment/Process/PELaunchServiceRegistry.h>
#import <LindChain/ProcEnvironment/Process/PEBootstrapRegistry.h>

@implementation PELaunchServiceRegistry {
    os_unfair_lock _lock;
    NSMutableArray<PELaunchService*> *_launchServices;
}

- (instancetype)init
{
    self = [super init];
    _launchServices = [[NSMutableArray alloc] init];
    _lock = OS_UNFAIR_LOCK_INIT;
    
    NSString *plistPath = [[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Shared"] stringByAppendingPathComponent:@"LaunchServices"];
    NSArray<NSString*> *plists = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:plistPath error:nil];
   
    for(NSString *plist in plists)
    {
        [_launchServices addObject:[PELaunchService launchServiceWithPlistPath:[plistPath stringByAppendingPathComponent:plist]]];
    }
    
    return self;
}

+ (instancetype)shared
{
    static PELaunchServiceRegistry *launchServiceRegistrySingleton = nil;
    static dispatch_once_t onceToken;
    static BOOL initializing = NO;
    
    if(initializing)
    {
        return launchServiceRegistrySingleton;
    }
    
    dispatch_once(&onceToken, ^{
        initializing = YES;
        launchServiceRegistrySingleton = [[PELaunchServiceRegistry alloc] init];
        initializing = NO;
    });
    
    return launchServiceRegistrySingleton;
}

- (NSXPCConnection *)connectToService:(NSString *)serviceIdentifier
                             protocol:(Protocol *)protocol
                             observer:(id)observer
                     observerProtocol:(Protocol *)observerProtocol
{
    NSXPCListenerEndpoint *endpoint = [[PEBootstrapRegistry shared] getEndpointWithServiceIdentifier:serviceIdentifier];
    if(!endpoint) return nil;
    
    NSXPCConnection *connection = [[NSXPCConnection alloc] initWithListenerEndpoint:endpoint];
    connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:protocol];
    connection.exportedInterface = [NSXPCInterface interfaceWithProtocol:observerProtocol];
    connection.exportedObject = observer;
    [connection resume];
    
    return connection;
}

- (PELaunchService *)serviceForIdentifier:(NSString *)serviceIdentifier
{
    os_unfair_lock_lock(&_lock);
    for(PELaunchService *item in _launchServices)
    {
        if([item.serviceIdentifier isEqualToString:serviceIdentifier])
        {
            os_unfair_lock_unlock(&_lock);
            return item;
        }
    }
    os_unfair_lock_unlock(&_lock);
    return nil;
}

@end
