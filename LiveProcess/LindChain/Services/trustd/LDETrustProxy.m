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
#import <LindChain/ProcEnvironment/Surface/trust.h>
#import <ServiceKit/ServiceKit.h>
#import <LindChain/Services/trustd/LDETrustProxy.h>
#import <LindChain/Services/trustd/LDETrustProtocol.h>
#import <CommonCrypto/CommonCrypto.h>
#import <mach-o/loader.h>
#import <mach-o/fat.h>

bool checkCodeSignature(const char* path);
NSString *cdHashOfExecutableAtPath(NSString *path);

@implementation LDETrustProxy

- (void)executableAllowedToExecutedAtPath:(NSString*)path
                                withReply:(void (^)(BOOL))reply
{
    reply(checkCodeSignature([path UTF8String]));
}

+ (NSString *)servcieIdentifier {
    return @"com.cr4zy.trustd";
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

- (void)getTokenOfExecutablePath:(NSString *)path
                       withReply:(void (^)(NSData *))reply
{
    ksurface_ent_mach_t mach;
    macho_read_token(path, &mach);
    
    NSData *data = [NSData dataWithBytes:&mach length:sizeof(ksurface_ent_mach_t)];
    reply(data);
}

@end
