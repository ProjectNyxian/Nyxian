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
#import <LindChain/Services/Service.h>
#import <LindChain/Services/trustd/LDETrustProxy.h>
#import <LindChain/Services/trustd/LDETrustProtocol.h>
#import <CommonCrypto/CommonCrypto.h>

bool checkCodeSignature(const char* path);

NSString *hashOfFileAtPath(NSString *path)
{
    NSFileHandle *fileHandle = [NSFileHandle fileHandleForReadingAtPath:path];
    if (!fileHandle) {
        return nil;
    }
    
    CC_SHA256_CTX context;
    CC_SHA256_Init(&context);
    
    while(true)
    {
        @autoreleasepool
        {
            NSData *fileData = [fileHandle readDataOfLength:1024 * 8];
            if (fileData.length == 0)
            {
                break;
            }
            CC_SHA256_Update(&context, [fileData bytes], (CC_LONG)[fileData length]);
        }
    }
    
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256_Final(digest, &context);
    
    NSMutableString *hashString = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for(int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++)
    {
        [hashString appendFormat:@"%02x", digest[i]];
    }
    
    return [hashString copy];
}

@implementation LDETrustProxy

- (void)getHashOfExecutableAtPath:(NSString*)path
                        withReply:(void (^)(NSString*))reply
{
    reply(hashOfFileAtPath(path));
}

- (void)executableAllowedToExecutedAtPath:(NSString*)path
                                withReply:(void (^)(BOOL))reply
{
    reply(checkCodeSignature([path UTF8String]));
}

@end

void TrustDaemonDaemonEntry(void)
{
    ServiceServer *serviceServer = [[ServiceServer alloc] initWithClass:[LDETrustProxy class] withProtocol:@protocol(LDETrustProtocol)];
    environment_proxy_set_endpoint_for_service_identifier([serviceServer getEndpointForConnection], @"com.cr4zy.trustd");
    CFRunLoopRun();
}
