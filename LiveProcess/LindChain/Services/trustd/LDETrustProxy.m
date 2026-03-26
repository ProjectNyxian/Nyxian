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

#import <LindChain/ProcEnvironment/environment.h>
#import <LindChain/ProcEnvironment/Surface/trust.h>
#import <ServiceKit/ServiceKit.h>
#import <LindChain/Services/trustd/LDETrustProxy.h>
#import <LindChain/Services/trustd/LDETrustProtocol.h>
#import <LindChain/ProcEnvironment/syscall.h>
#import <CommonCrypto/CommonCrypto.h>
#import <mach-o/loader.h>
#import <mach-o/fat.h>
#import <LindChain/ProcEnvironment/Surface/entitlement.h>

bool checkCodeSignature(const char* path);
NSString *cdHashOfExecutableAtPath(NSString *path);

@implementation LDETrustProxy

- (void)executableAllowedToExecutedAtPath:(NSString*)path
                                withReply:(void (^)(BOOL))reply
{
    reply(checkCodeSignature([path UTF8String]));
}

+ (NSString *)servcieIdentifier {
    return @"com.cr4zy.ksurfaced";
}

+ (Protocol*)serviceProtocol
{
    return @protocol(LDETrustProtocol);
}

+ (Protocol*)observerProtocol
{
    return nil;
}

- (void)clientDidConnectWithConnection:(NSXPCConnection*)client
{
    return;
}

- (void)entitlementsForExecutableAtPath:(NSString *)path
                              withReply:(void (^)(PEEntitlement))reply
{
    static int64_t ret;
    static uint8_t pub_key[512];
    static size_t pub_key_len = 512;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        ret = environment_syscall(SYS_getpk, pub_key, &pub_key_len);
    });
    
    if(ret != 0)
    {
        reply(PEEntitlementNone);
        return;
    }
    
    ksurface_ent_result_t mach;
    macho_read_token([path UTF8String], &mach);
    
    ksurface_return_t ksr = entitlement_mach_verify(&mach, pub_key, pub_key_len);
    
    if(ksr != KERN_SUCCESS)
    {
        reply(PEEntitlementNone);
        return;
    }
    
    reply(mach.blob.entitlement);
}

@end
