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

#import <LindChain/ProcEnvironment/environment.h>
#import <LindChain/ProcEnvironment/Object/MachOObject.h>
#import <LindChain/LiveContainer/LCUtils.h>
#import <LindChain/LiveContainer/LCMachOUtils.h>

@implementation MachOObject

+ (BOOL)isBinarySignedAtPath:(NSString *)path
{
    return checkCodeSignature([path UTF8String]);
}

+ (BOOL)signBinaryAtPath:(NSString*)path
{
    environment_must_be_role(EnvironmentRoleHost);
    
    __block NSError *error = nil;
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString *bundlePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"app"]];
    NSString *binPath = [bundlePath stringByAppendingPathComponent:@"main"];
    NSString *infoPath = [bundlePath stringByAppendingPathComponent:@"Info.plist"];
    
    /* create bundle structure */
    [fm createDirectoryAtPath:bundlePath withIntermediateDirectories:YES attributes:nil error:nil];
    
    /* create pseudo info.plist TODO: actual make a single macho signer */
    [[NSPropertyListSerialization dataWithPropertyList:@{
        @"CFBundleIdentifier" : [[NSBundle mainBundle] bundleIdentifier],
        @"CFBundleExecutable" : @"main"
    } format:NSPropertyListXMLFormat_v1_0 options:0 error:&error] writeToFile:infoPath atomically:YES];
    
    if(error != nil)
    {
        return NO;
    }
    
    /* run signer~~ UwU */
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [LCUtils signAppBundleWithZSign:[NSURL fileURLWithPath:bundlePath] completionHandler:^(BOOL succeeded, NSError *error){
        error = error;
        dispatch_semaphore_signal(sema);
    }];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    
    if(error != nil)
    {
        return NO;
    }
    
    if([self isBinarySignedAtPath:binPath])
    {
        [fm moveItemAtPath:binPath toPath:path error:nil];
        [fm removeItemAtPath:bundlePath error:nil];
        return YES;
    }
    
    [fm removeItemAtPath:bundlePath error:nil];
    return NO;
}

- (BOOL)signAndWriteBack
{
    environment_must_be_role(EnvironmentRoleHost);
    
    __block NSError *error = nil;
    
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString *bundlePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"app"]];
    NSString *binPath = [bundlePath stringByAppendingPathComponent:@"main"];
    NSString *infoPath = [bundlePath stringByAppendingPathComponent:@"Info.plist"];
    
    /* create bundle structure */
    [fm createDirectoryAtPath:bundlePath withIntermediateDirectories:YES attributes:nil error:nil];
    
    /* create pseudo info.plist TODO: actual make a single macho signer */
    [[NSPropertyListSerialization dataWithPropertyList:@{
        @"CFBundleIdentifier" : [[NSBundle mainBundle] bundleIdentifier],
        @"CFBundleExecutable" : @"main"
    } format:NSPropertyListXMLFormat_v1_0 options:0 error:&error] writeToFile:infoPath atomically:YES];
    
    if(error != nil)
    {
        return NO;
    }
    
    /* write binary from file descriptor to our selves */
    if(![self writeOut:binPath]) return NO;
    
    /* run signer~~ UwU */
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [LCUtils signAppBundleWithZSign:[NSURL fileURLWithPath:bundlePath] completionHandler:^(BOOL succeeded, NSError *error){
        error = error;
        dispatch_semaphore_signal(sema);
    }];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    
    if(error != nil)
    {
        return NO;
    }
    
    if([self.class isBinarySignedAtPath:binPath] &&
       [self writeIn:binPath])
    {
        [fm removeItemAtPath:bundlePath error:nil];
        return YES;
    }
    
    [fm removeItemAtPath:bundlePath error:nil];
    return NO;
}

@end
