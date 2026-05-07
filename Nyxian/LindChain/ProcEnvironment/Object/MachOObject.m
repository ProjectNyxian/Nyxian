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

#import <LindChain/ProcEnvironment/environment.h>
#import <LindChain/ProcEnvironment/Object/MachOObject.h>
#import <LindChain/LiveContainer/LCUtils.h>
#import <LindChain/LiveContainer/LCMachOUtils.h>
#import <LindChain/LiveContainer/ZSign/zsigner.h>

@implementation MachOObject

+ (instancetype)objectForFDObject:(FDObject*)object
{
    MachOObject *mobject = [[self alloc] init];
    mobject.fd = object.fd;
    return mobject;
}

+ (BOOL)isBinarySignedAtPath:(NSString *)path
{
    return checkCodeSignature([path UTF8String]);
}

+ (BOOL)signBinaryAtPath:(NSString*)path
{
    /* run signer~~ give it to me apple~, OMG OMG NOT THAT FAST. GOD IS THAT HUGE */
    return [LCUtils signMachOAtURL:[NSURL fileURLWithPath:path]];
}

- (BOOL)signAndWriteBack
{
    NSString *binPath = [NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString];
    
    /* write binary from file descriptor to our selves */
    if(![self writeOut:binPath])
    {
        return NO;
    }
    
    /* run signer~~ UwU */
    BOOL success = [MachOObject signBinaryAtPath:binPath];
    
    if(!success)
    {
        [[NSFileManager defaultManager] removeItemAtPath:binPath error:nil];
        return NO;
    }
    
    if(![self writeIn:binPath])
    {
        [[NSFileManager defaultManager] removeItemAtPath:binPath error:nil];
        return NO;
    }
    
    [[NSFileManager defaultManager] removeItemAtPath:binPath error:nil];
    return success;
}

@end
