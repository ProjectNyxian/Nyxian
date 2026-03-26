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

#import <LindChain/Services/trustd/LDETrust.h>
#import <LindChain/Services/trustd/LDETrustProtocol.h>
#import <LindChain/LaunchServices/LaunchService.h>

@implementation LDETrust

- (instancetype)init
{
    self = [super init];
    return self;
}

+ (instancetype)shared
{
    static LDETrust *trustSingleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        trustSingleton = [[LDETrust alloc] init];
    });
    return trustSingleton;
}

- (BOOL)connect
{
    if(self.connection)
    {
        return YES;
    }
    
    __weak typeof(self) weakSelf = self;
    _connection = nil;
    LaunchServices *launchServices = [LaunchServices shared];
    
    if(launchServices != nil)
    {
        _connection = [launchServices connectToService:@"com.cr4zy.ksurfaced" protocol:@protocol(LDETrustProtocol) observer:nil observerProtocol:nil];
        _connection.invalidationHandler = ^{
            __strong typeof(self) strongSelf = weakSelf;
            if(!strongSelf) return;
            
            strongSelf.connection = nil;
            [strongSelf connect];
        };
        
        return _connection != nil;
    }
    
    return NO;
}

- (BOOL)executableAllowedToLaunchAtPath:(NSString*)path
{
    // The only current pitfall of Nyxians security is the possibilities of file protections and this stuff
    // RIGHT HERE
    if([path isEqualToString:@"/usr/libexec/ksurfaced"] ||
       [path isEqualToString:@"/usr/libexec/installd"])
    {
        return YES;
    }
    
    [self connect];
    
    __block BOOL allowedToLaunch = NO;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    
    id proxy = [_connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
        /* semaphores remember the signal, it doesnt have to catch them in time */
        dispatch_semaphore_signal(sema);
    }];
    
    if(proxy == NULL)
    {
        /* semaphores remember the signal, it doesnt have to catch them in time */
        dispatch_semaphore_signal(sema);
    }
    else
    {
        [proxy executableAllowedToExecutedAtPath:path withReply:^(BOOL allowed){
            allowedToLaunch = allowed;
            dispatch_semaphore_signal(sema);
        }];
    }
    
    dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)));
    
    return allowedToLaunch;
}

- (PEEntitlement)entitlementsOfExecutableAtPath:(NSString*)path
{
    // The only current pitfall of Nyxians security is the possibilities of file protections and this stuff
    // RIGHT HERE
    if([path isEqualToString:@"/usr/libexec/ksurfaced"] ||
       [path isEqualToString:@"/usr/libexec/installd"])
    {
        return PEEntitlementSystemDaemon;
    }
    
    [self connect];
    
    __block PEEntitlement entitlements = PEEntitlementNone;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    
    id proxy = [_connection remoteObjectProxyWithErrorHandler:^(NSError *error) {
        /* semaphores remember the signal, it doesnt have to catch them in time */
        dispatch_semaphore_signal(sema);
    }];
    
    if(proxy == NULL)
    {
        /* semaphores remember the signal, it doesnt have to catch them in time */
        dispatch_semaphore_signal(sema);
    }
    else
    {
        [proxy entitlementsForExecutableAtPath:path withReply:^(PEEntitlement replyEntitlements){
            entitlements = replyEntitlements;
            dispatch_semaphore_signal(sema);
        }];
    }
    
    dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)));
    
    return entitlements;
}

@end
