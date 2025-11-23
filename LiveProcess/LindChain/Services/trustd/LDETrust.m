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

+ (NSString*)entHashOfExecutableAtPath:(NSString *)path
{
    __block NSString *entHashExport = nil;
    [[LaunchServices shared] execute:^(NSObject<LDETrustProtocol> *remoteObject){
        dispatch_semaphore_t sema = dispatch_semaphore_create(0);
        [remoteObject getHashOfExecutableAtPath:path withReply:^(NSString *entHash){
            entHashExport = entHash;
            dispatch_semaphore_signal(sema);
        }];
        dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    } byEstablishingConnectionToServiceWithServiceIdentifier:@"com.cr4zy.trustd" compliantToProtocol:@protocol(LDETrustProtocol)];
    return entHashExport;
}

@end
