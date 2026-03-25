/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 cr4zyengineer

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

#import <LindChain/LaunchServices/LaunchService.h>
#import <LindChain/ProcEnvironment/Server/Server.h>
#import <LindChain/ProcEnvironment/Object/FDMapObject.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>

@implementation LaunchService

- (instancetype)initWithPlistPath:(NSString *)plistPath
{
    self = [super init];
    _dictionary = [NSDictionary dictionaryWithContentsOfFile:plistPath];
    
    [self ignition];
    
    return self;
}

- (void)ignition
{
    // Spawn process
    NSMutableDictionary *mutableDictionary = [_dictionary mutableCopy];
    
#if DEBUG
    FDMapObject *mapObject = [FDMapObject emptyMap];
    [mapObject appendFileDescriptor:STDIN_FILENO withMappingToLoc:STDIN_FILENO];
    [mapObject appendFileDescriptor:STDOUT_FILENO withMappingToLoc:STDOUT_FILENO];
    [mapObject appendFileDescriptor:STDERR_FILENO withMappingToLoc:STDERR_FILENO];
    [mutableDictionary setObject:mapObject forKey:@"PEMapObject"];
#endif /* DEBUG */
    
    pid_t pid = [[LDEProcessManager shared] spawnProcessWithItems:[mutableDictionary copy] withKernelSurfaceProcess:kernel_proc_];
    if(pid == 0) [self ignition];
    
    // Get process
    _process = [[LDEProcessManager shared] processForProcessIdentifier:pid];
    if(_process == nil) [self ignition];
    
    // Now assign handlers
    if([self shouldAutorestart])
    {
        __weak typeof(self) weakSelf = self;
        [_process setExitingCallback:^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [weakSelf ignition];
            });
        }];
    }
}

- (NSString*)serviceIdentifier
{
    NSString *serviceIdentifier = [[self dictionary] objectForKey:@"PEServiceIdentifier"];
    if(!serviceIdentifier) serviceIdentifier = @"no-service";
    return serviceIdentifier;
}

- (BOOL)isServiceWithServiceIdentifier:(NSString *)serviceIdentifier
{
    NSString *mustMatchServiceIdentifier = [[self dictionary] objectForKey:@"PEServiceIdentifier"];
    if(!serviceIdentifier || !mustMatchServiceIdentifier || ![mustMatchServiceIdentifier isEqualToString:serviceIdentifier])
        return NO;
    else
        return YES;
}

- (BOOL)shouldAutorestart
{
    NSNumber *num = [_dictionary valueForKey:@"PEShouldAutorestart"];
    return (num == nil) ? NO : num.boolValue;
}

- (NSString*)executablePath
{
    NSString *executablePath = [[self dictionary] objectForKey:@"PEExecutablePath"];
    if(!executablePath) executablePath = @"no-exec-path";
    return executablePath;
}

- (uid_t)userIdentifier
{
    NSNumber *userIdentifierObject = [_dictionary objectForKey:@"PEUserIdentifier"];
    return (userIdentifierObject == nil) ? 501 : userIdentifierObject.unsignedIntValue;
}

- (gid_t)groupIdentifier
{
    NSNumber *groupIdentifierObject = [_dictionary objectForKey:@"PEGroupIdentifier"];
    return (groupIdentifierObject == nil) ? 501 : groupIdentifierObject.unsignedIntValue;
}

- (NSString*)integratedServiceName
{
    NSString *integratedServiceName = [[self dictionary] objectForKey:@"PEIntegratedServiceName"];
    if(!integratedServiceName) integratedServiceName = @"no-service-name";
    return integratedServiceName;
}

@end

@implementation LaunchServices

- (instancetype)init
{
    self = [super init];
    _launchServices = [[NSMutableArray alloc] init];
    _lock = OS_UNFAIR_LOCK_INIT;
    
    NSFileManager *fm = [[NSFileManager alloc] init];
    NSString *plistPath = [[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Shared"] stringByAppendingPathComponent:@"LaunchServices"];
    NSArray<NSString*> *plists = [fm contentsOfDirectoryAtPath:plistPath error:nil];
   
    for(NSString *plist in plists)
    {
        [_launchServices addObject:[[LaunchService alloc] initWithPlistPath:[plistPath stringByAppendingPathComponent:plist]]];
    }
    
    return self;
}

+ (instancetype)shared
{
    static LaunchServices *launchServicesSingleton = nil;
    static dispatch_once_t onceToken;
    static BOOL initializing = NO;
    
    if(initializing)
    {
        return launchServicesSingleton;
    }
    
    dispatch_once(&onceToken, ^{
        initializing = YES;
        launchServicesSingleton = [[LaunchServices alloc] init];
        initializing = NO;
    });
    
    return launchServicesSingleton;
}

- (NSXPCConnection *)connectToService:(NSString *)serviceIdentifier
                             protocol:(Protocol *)protocol
                             observer:(id)observer
                     observerProtocol:(Protocol *)observerProtocol
{
    NSXPCListenerEndpoint *endpoint = [[LDEBootstrapRegistry shared] getEndpointWithServiceIdentifier:serviceIdentifier];
    if (!endpoint) return nil;
    
    NSXPCConnection *connection = [[NSXPCConnection alloc] initWithListenerEndpoint:endpoint];
    connection.remoteObjectInterface = [NSXPCInterface interfaceWithProtocol:protocol];
    connection.exportedInterface = [NSXPCInterface interfaceWithProtocol:observerProtocol];
    connection.exportedObject = observer;
    [connection resume];
    
    return connection;
}

@end
