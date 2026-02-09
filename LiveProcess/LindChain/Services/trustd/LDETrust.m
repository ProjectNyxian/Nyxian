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

#import <LindChain/Services/trustd/LDETrust.h>
#import <LindChain/Services/trustd/LDETrustProtocol.h>
#import <LindChain/LaunchServices/LaunchService.h>

@implementation LDETrust

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        [self connect];
    }
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
    __weak typeof(self) weakSelf = self;
    _connection = nil;
    LaunchServices *launchServices = [LaunchServices shared];
    
    if(launchServices != nil)
    {
        NSLog(@"connecting to installd");
        _connection = [launchServices connectToService:@"com.cr4zy.trustd" protocol:@protocol(LDETrustProtocol) observer:nil observerProtocol:nil];
        _connection.invalidationHandler = ^{
            [weakSelf connect];
        };
        
        return YES;
    }
    
    return NO;
}

- (NSString*)entHashOfExecutableAtPath:(NSString *)path
{
    // The only current pitfall of Nyxians security is the possibilities of file protections and this stuff
    // RIGHT HERE
    if([path isEqualToString:@"/usr/libexec/trustd"] ||
       [path isEqualToString:@"/usr/libexec/installd"])
    {
        return @"com.cr4zy.nyxian.daemon.trustcache_daemon";
    }
    
    if(_connection == nil && ![self connect])
    {
        return nil;
    }
    
    __block NSString *entHashExport = nil;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [_connection.remoteObjectProxy getHashOfExecutableAtPath:path withReply:^(NSString *entHash){
        entHashExport = entHash;
        dispatch_semaphore_signal(sema);
    }];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    
    return entHashExport;
}

- (BOOL)executableAllowedToLaunchAtPath:(NSString*)path
{
    // The only current pitfall of Nyxians security is the possibilities of file protections and this stuff
    // RIGHT HERE
    if([path isEqualToString:@"/usr/libexec/trustd"] ||
       [path isEqualToString:@"/usr/libexec/installd"])
    {
        return YES;
    }
    
    if(_connection == nil && ![self connect])
    {
        return NO;
    }
    
    __block BOOL allowedToLaunch = NO;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [_connection.remoteObjectProxy executableAllowedToExecutedAtPath:path withReply:^(BOOL allowed){
        allowedToLaunch = allowed;
        dispatch_semaphore_signal(sema);
    }];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    
    return allowedToLaunch;
}

@end
