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
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString *bundlePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"app"]];
    NSString *binPath = [bundlePath stringByAppendingPathComponent:@"main"];
    NSString *infoPath = [bundlePath stringByAppendingPathComponent:@"Info.plist"];
    
    // Create bundle structure
    [fm createDirectoryAtPath:bundlePath withIntermediateDirectories:YES attributes:nil error:nil];
    
    // Write Info.plist with hash marker
    NSDictionary *plistDict = @{
        @"CFBundleIdentifier" : [[NSBundle mainBundle] bundleIdentifier],
        @"CFBundleExecutable" : @"main",
        @"CFBundleVersion"    : @"1.0.0"
    };
    NSData *plistData = [NSPropertyListSerialization dataWithPropertyList:plistDict
                                                                   format:NSPropertyListXMLFormat_v1_0
                                                                  options:0
                                                                    error:nil];
    [plistData writeToFile:infoPath atomically:YES];
    [fm copyItemAtPath:path toPath:binPath error:nil];
    
    // Run signer
    __block NSError *error = nil;
    [LCUtils signAppBundleWithZSign:[NSURL fileURLWithPath:bundlePath] completionHandler:^(BOOL succeeded, NSError *error){
        error = error;
    }];
    
    if(error != nil)
    {
        return NO;
    }
    
    if(checkCodeSignature([binPath UTF8String]))
    {
        [fm moveItemAtPath:binPath toPath:path error:nil];
        [fm removeItemAtPath:bundlePath error:nil];
        return YES;
    }
    
    return NO;
}

- (BOOL)signAndWriteBack
{
    environment_must_be_role(EnvironmentRoleHost);
    NSFileManager *fm = [NSFileManager defaultManager];
    
    NSString *bundlePath = [NSTemporaryDirectory() stringByAppendingPathComponent:[[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:@"app"]];
    NSString *binPath = [bundlePath stringByAppendingPathComponent:@"main"];
    NSString *infoPath = [bundlePath stringByAppendingPathComponent:@"Info.plist"];
    
    // Create bundle structure
    [fm createDirectoryAtPath:bundlePath withIntermediateDirectories:YES attributes:nil error:nil];
    
    // Write Info.plist with hash marker
    NSDictionary *plistDict = @{
        @"CFBundleIdentifier" : [[NSBundle mainBundle] bundleIdentifier],
        @"CFBundleExecutable" : @"main",
        @"CFBundleVersion"    : @"1.0.0"
    };
    NSData *plistData = [NSPropertyListSerialization dataWithPropertyList:plistDict
                                                                   format:NSPropertyListXMLFormat_v1_0
                                                                  options:0
                                                                    error:nil];
    [plistData writeToFile:infoPath atomically:YES];
    if(![self writeOut:binPath]) return NO;
    
    // Run signer
    __block NSError *error = nil;
    [LCUtils signAppBundleWithZSign:[NSURL fileURLWithPath:bundlePath] completionHandler:^(BOOL succeeded, NSError *error){
        error = error;
    }];
    
    if(error != nil)
    {
        return NO;
    }
    
    if(checkCodeSignature([binPath UTF8String]))
    {
        [fm moveItemAtPath:binPath toPath:bundlePath error:nil];
        [fm removeItemAtPath:bundlePath error:nil];
        return YES;
    }
    
    return NO;
}

@end
