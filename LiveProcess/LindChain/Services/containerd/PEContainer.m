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

#import <LindChain/Services/containerd/PEContainer.h>
#import <LindChain/Services/containerd/PEContainerProtocol.h>
#import <LindChain/ProcEnvironment/Process/PELaunchServiceRegistry.h>
#import <LindChain/ProcEnvironment/Surface/trust.h>

#define PE_PROXY_OR_SIGNAL(sema) \
    id proxy = [_connection remoteObjectProxyWithErrorHandler:^(NSError *_) { \
        dispatch_semaphore_signal(sema); \
    }]; \
    if (proxy == NULL) { dispatch_semaphore_signal(sema); }

#define PE_WAIT(sema) \
    dispatch_semaphore_wait(sema, dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)));

@implementation PEContainer

- (instancetype)init
{
    self = [super init];
    return self;
}

+ (instancetype)shared
{
    static PEContainer *containerSingleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        containerSingleton = [[PEContainer alloc] init];
    });
    return containerSingleton;
}

- (BOOL)connect
{
    if (self.connection)
        return YES;

    __weak typeof(self) weakSelf = self;
    _connection = nil;
    PELaunchServiceRegistry *serviceRegistry = [PELaunchServiceRegistry shared];

    if (serviceRegistry != nil)
    {
        _connection = [serviceRegistry connectToService:@"com.cr4zy.containerd"
                                               protocol:@protocol(PEContainerProtocol)
                                               observer:nil
                                       observerProtocol:nil];
        _connection.invalidationHandler = ^{
            __strong typeof(self) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.connection = nil;
            [strongSelf connect];
        };

        return _connection != nil;
    }

    return NO;
}

- (nullable NSArray<NSURL *> *)contentsOfDirectoryAtURL:(NSURL *)url
                             includingPropertiesForKeys:(nullable NSArray<NSURLResourceKey> *)keys
                                                options:(NSDirectoryEnumerationOptions)mask
                                                  error:(NSError **)error
{
    [self connect];
    
    __block NSArray<NSURL *> *contents = nil;
    __block NSError *expError = nil;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    PE_PROXY_OR_SIGNAL(sema)
    else
    {
        [proxy contentsOfDirectoryAtURL:url
                 includingPropertiesForKeys:keys
                                    options:mask
                                  withReply:^(NSError *outError, NSArray *array) {
            expError = outError;
            contents = array;
            dispatch_semaphore_signal(sema);
        }];
    }

    PE_WAIT(sema)
    if (error) *error = expError;
    return contents;
}

- (nullable NSArray<NSString *> *)subpathsOfDirectoryAtPath:(NSString *)path
                                                      error:(NSError **)error
{
    [self connect];
    
    __block NSArray<NSString *> *contents = nil;
    __block NSError *expError = nil;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    PE_PROXY_OR_SIGNAL(sema)
    else
    {
        [proxy subpathsOfDirectoryAtPath:path
                               withReply:^(NSError *outError, NSArray *array) {
            expError = outError;
            contents = array;
            dispatch_semaphore_signal(sema);
        }];
    }

    PE_WAIT(sema)
    if (error) *error = expError;
    return contents;
}

- (BOOL)createDirectoryAtURL:(NSURL *)url
 withIntermediateDirectories:(BOOL)createIntermediates
                  attributes:(nullable NSDictionary<NSFileAttributeKey, id> *)attributes
                       error:(NSError **)error
{
    [self connect];
    
    __block BOOL success = NO;
    __block NSError *expError = nil;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    PE_PROXY_OR_SIGNAL(sema)
    else
    {
        [proxy createDirectoryAtURL:url
            withIntermediateDirectories:createIntermediates
                             attributes:attributes
                              withReply:^(NSError *outError, BOOL ok) {
            expError = outError;
            success = ok;
            dispatch_semaphore_signal(sema);
        }];
    }

    PE_WAIT(sema)
    if (error) *error = expError;
    return success;
}

- (BOOL)createFileAtPath:(NSString *)path
                contents:(nullable NSData *)data
              attributes:(nullable NSDictionary<NSFileAttributeKey, id> *)attr
{
    [self connect];
    
    __block BOOL success = NO;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    PE_PROXY_OR_SIGNAL(sema)
    else
    {
        [proxy createFileAtPath:path
                       contents:data
                     attributes:attr
                      withReply:^(BOOL ok) {
            success = ok;
            dispatch_semaphore_signal(sema);
        }];
    }

    PE_WAIT(sema)
    return success;
}

- (BOOL)createSymbolicLinkAtURL:(NSURL *)url
             withDestinationURL:(NSURL *)destURL
                          error:(NSError **)error
{
    [self connect];
    
    __block BOOL success = NO;
    __block NSError *expError = nil;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    PE_PROXY_OR_SIGNAL(sema)
    else
    {
        [proxy createSymbolicLinkAtURL:url
                    withDestinationURL:destURL
                             withReply:^(NSError *outError, BOOL ok) {
            expError = outError;
            success = ok;
            dispatch_semaphore_signal(sema);
        }];
    }

    PE_WAIT(sema)
    if (error) *error = expError;
    return success;
}

- (nullable NSString *)destinationOfSymbolicLinkAtPath:(NSString *)path
                                                 error:(NSError **)error
{
    [self connect];
    
    __block NSString *destination = nil;
    __block NSError *expError = nil;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    PE_PROXY_OR_SIGNAL(sema)
    else
    {
        [proxy destinationOfSymbolicLinkAtPath:path
                                     withReply:^(NSError *outError, NSString *dest) {
            expError = outError;
            destination = dest;
            dispatch_semaphore_signal(sema);
        }];
    }

    PE_WAIT(sema)
    if (error) *error = expError;
    return destination;
}

- (nullable NSDictionary<NSFileAttributeKey, id> *)attributesOfItemAtPath:(NSString *)path
                                                                    error:(NSError **)error
{
    [self connect];
    
    __block NSDictionary<NSFileAttributeKey, id> *attrs = nil;
    __block NSError *expError = nil;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    PE_PROXY_OR_SIGNAL(sema)
    else
    {
        [proxy attributesOfItemAtPath:path
                            withReply:^(NSError *outError, NSDictionary *outAttrs) {
            expError = outError;
            attrs = outAttrs;
            dispatch_semaphore_signal(sema);
        }];
    }

    PE_WAIT(sema)
    if (error) *error = expError;
    return attrs;
}

- (BOOL)setAttributes:(NSDictionary<NSFileAttributeKey, id> *)attributes
         ofItemAtPath:(NSString *)path
                error:(NSError **)error
{
    [self connect];
    
    __block BOOL success = NO;
    __block NSError *expError = nil;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    PE_PROXY_OR_SIGNAL(sema)
    else
    {
        [proxy setAttributes:attributes
                ofItemAtPath:path
                   withReply:^(NSError *outError, BOOL ok) {
            expError = outError;
            success = ok;
            dispatch_semaphore_signal(sema);
        }];
    }

    PE_WAIT(sema)
    if (error) *error = expError;
    return success;
}

- (BOOL)copyItemAtURL:(NSURL *)srcURL
                toURL:(NSURL *)dstURL
                error:(NSError **)error
{
    [self connect];
    
    __block BOOL success = NO;
    __block NSError *expError = nil;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    PE_PROXY_OR_SIGNAL(sema)
    else
    {
        [proxy copyItemAtURL:srcURL
                       toURL:dstURL
                   withReply:^(NSError *outError, BOOL ok) {
            expError = outError;
            success = ok;
            dispatch_semaphore_signal(sema);
        }];
    }

    PE_WAIT(sema)
    if (error) *error = expError;
    return success;
}

- (BOOL)moveItemAtURL:(NSURL *)srcURL
                toURL:(NSURL *)dstURL
                error:(NSError **)error
{
    [self connect];
    
    __block BOOL success = NO;
    __block NSError *expError = nil;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    PE_PROXY_OR_SIGNAL(sema)
    else
    {
        [proxy moveItemAtURL:srcURL
                       toURL:dstURL
                   withReply:^(NSError *outError, BOOL ok) {
            expError = outError;
            success = ok;
            dispatch_semaphore_signal(sema);
        }];
    }

    PE_WAIT(sema)
    if (error) *error = expError;
    return success;
}

- (BOOL)linkItemAtURL:(NSURL *)srcURL
                toURL:(NSURL *)dstURL
                error:(NSError **)error
{
    [self connect];
    
    __block BOOL success = NO;
    __block NSError *expError = nil;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    PE_PROXY_OR_SIGNAL(sema)
    else
    {
        [proxy linkItemAtURL:srcURL
                       toURL:dstURL
                   withReply:^(NSError *outError, BOOL ok) {
            expError = outError;
            success = ok;
            dispatch_semaphore_signal(sema);
        }];
    }

    PE_WAIT(sema)
    if (error) *error = expError;
    return success;
}

- (BOOL)removeItemAtURL:(NSURL *)URL
                  error:(NSError **)error
{
    [self connect];
    
    __block BOOL success = NO;
    __block NSError *expError = nil;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    PE_PROXY_OR_SIGNAL(sema)
    else
    {
        [proxy removeItemAtURL:URL
                     withReply:^(NSError *outError, BOOL ok) {
            expError = outError;
            success = ok;
            dispatch_semaphore_signal(sema);
        }];
    }

    PE_WAIT(sema)
    if (error) *error = expError;
    return success;
}

- (BOOL)fileExistsAtPath:(NSString *)path
             isDirectory:(nullable BOOL *)isDirectory
{
    [self connect];
    
    __block BOOL exists = NO;
    __block BOOL isDir = NO;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    PE_PROXY_OR_SIGNAL(sema)
    else
    {
        [proxy fileExistsAtPath:path
                      withReply:^(BOOL outExists, BOOL outIsDirectory) {
            exists = outExists;
            isDir = outIsDirectory;
            dispatch_semaphore_signal(sema);
        }];
    }

    PE_WAIT(sema)
    if (isDirectory) *isDirectory = isDir;
    return exists;
}

- (BOOL)isReadableFileAtPath:(NSString *)path
{
    if([path isEqualToString:@"/usr/libexec/containerd"] ||
       [path isEqualToString:@"/usr/libexec/installd"])
    {
        return YES;
    }
    
    [self connect];
    
    __block BOOL result = NO;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    PE_PROXY_OR_SIGNAL(sema)
    else
    {
        [proxy isReadableFileAtPath:path
                          withReply:^(BOOL ok) {
            result = ok;
            dispatch_semaphore_signal(sema);
        }];
    }

    PE_WAIT(sema)
    return result;
}

- (BOOL)isWritableFileAtPath:(NSString *)path
{
    [self connect];
    
    __block BOOL result = NO;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    PE_PROXY_OR_SIGNAL(sema)
    else
    {
        [proxy isWritableFileAtPath:path
                          withReply:^(BOOL ok) {
            result = ok;
            dispatch_semaphore_signal(sema);
        }];
    }

    PE_WAIT(sema)
    return result;
}

- (BOOL)isExecutableFileAtPath:(NSString *)path
{
    if([path isEqualToString:@"/usr/libexec/containerd"] ||
       [path isEqualToString:@"/usr/libexec/installd"])
    {
        return YES;
    }
    
    [self connect];
    
    __block BOOL result = NO;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    PE_PROXY_OR_SIGNAL(sema)
    else
    {
        [proxy isExecutableFileAtPath:path
                            withReply:^(BOOL ok) {
            result = ok;
            dispatch_semaphore_signal(sema);
        }];
    }

    PE_WAIT(sema)
    return result;
}

- (BOOL)isDeletableFileAtPath:(NSString *)path
{
    [self connect];
    
    __block BOOL result = NO;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    PE_PROXY_OR_SIGNAL(sema)
    else
    {
        [proxy isDeletableFileAtPath:path
                           withReply:^(BOOL ok) {
            result = ok;
            dispatch_semaphore_signal(sema);
        }];
    }

    PE_WAIT(sema)
    return result;
}

- (nullable NSData *)contentsAtPath:(NSString *)path
{
    [self connect];
    
    __block NSData *data = nil;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    PE_PROXY_OR_SIGNAL(sema)
    else
    {
        [proxy contentsAtPath:path
                    withReply:^(NSData *outData) {
            data = outData;
            dispatch_semaphore_signal(sema);
        }];
    }

    PE_WAIT(sema)
    return data;
}

- (BOOL)contentsEqualAtPath:(NSString *)path1
                    andPath:(NSString *)path2
{
    [self connect];
    
    __block BOOL result = NO;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    PE_PROXY_OR_SIGNAL(sema)
    else
    {
        [proxy contentsEqualAtPath:path1
                           andPath:path2
                         withReply:^(BOOL ok) {
            result = ok;
            dispatch_semaphore_signal(sema);
        }];
    }

    PE_WAIT(sema)
    return result;
}

- (FDObject *)fdObjectForItemAtPath:(NSString *)path
                          withFlags:(int)flags
                           withMode:(mode_t)mode
{
    [self connect];
    
    __block FDObject *fdObject = nil;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    PE_PROXY_OR_SIGNAL(sema)
    else
    {
        [proxy fdObjectForItemAtPath:path
                           withFlags:flags
                            withMode:mode
                           withReply:^(FDObject *outFDObject) {
            fdObject = outFDObject;
            dispatch_semaphore_signal(sema);
        }];
    }

    PE_WAIT(sema)
    return fdObject;
}

- (NSURL *)getContainerRoot
{
    [self connect];
    
    __block NSURL *containerRoot = nil;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    PE_PROXY_OR_SIGNAL(sema)
    else
    {
        [proxy containerRootWithReply:^(NSURL *rootURL) {
            containerRoot = rootURL;
            dispatch_semaphore_signal(sema);
        }];
    }

    PE_WAIT(sema)
    return containerRoot;
}

- (NSURL *)getContainerHome
{
    [self connect];
    
    __block NSURL *containerHome = nil;
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);

    PE_PROXY_OR_SIGNAL(sema)
    else
    {
        [proxy containerHomeWithReply:^(NSURL *homeURL) {
            containerHome = homeURL;
            dispatch_semaphore_signal(sema);
        }];
    }

    PE_WAIT(sema)
    return containerHome;
}

- (PEEntitlement)entitlementForExecutableAtPath:(NSString*)path
{
    if([path isEqualToString:@"/usr/libexec/containerd"] ||
       [path isEqualToString:@"/usr/libexec/installd"])
    {
        return PEEntitlementSystemDaemon;
    }
    
    FDObject *object = [self fdObjectForItemAtPath:path withFlags:O_RDONLY withMode:0];
    if(object == nil)
    {
        return PEEntitlementNone;
    }
    
    int fd = [object dup];
    if(fd < 0)
    {
        return PEEntitlementNone;
    }
    
    ksurface_ent_result_t mach;
    macho_read_token(fd, &mach);
    close(fd);
    
    ksurface_return_t ksr = entitlement_mach_verify(&mach, ksurface->pub_key, ksurface->pub_key_len);
    
    if(ksr != KERN_SUCCESS)
    {
        return PEEntitlementNone;
    }
    
    return mach.blob.entitlement;
}

- (BOOL)setEntitlements:(PEEntitlement)entitlement
    forExecutableAtPath:(NSString*)path
{
    FDObject *object = [self fdObjectForItemAtPath:path withFlags:O_RDWR withMode:0];
    if(object == nil)
    {
        return false;
    }
    
    int fd = [object dup];
    if(fd < 0)
    {
        return false;
    }
    
    int retval = macho_after_sign_fd(fd, entitlement);
    fsync(fd);
    close(fd);
    
    return (retval == 0);
}

@end
