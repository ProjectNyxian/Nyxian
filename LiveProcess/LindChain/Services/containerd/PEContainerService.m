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

#import <LindChain/Services/containerd/PEContainerService.h>

@implementation PEContainerService {
    NSFileManager *_fileManager;
}

- (instancetype)init
{
    self = [super init];
    _fileManager = NSFileManager.defaultManager;
    return self;
}

+ (NSString *)servcieIdentifier {
    return @"com.cr4zy.containerd";
}

+ (Protocol*)serviceProtocol
{
    return @protocol(PEContainerProtocol);
}

+ (Protocol*)observerProtocol
{
    return nil;
}

- (void)clientDidConnectWithConnection:(NSXPCConnection*)client
{
    return;
}

- (void)contentsOfDirectoryAtURL:(NSURL *)url
      includingPropertiesForKeys:(nullable NSArray<NSURLResourceKey> *)keys
                         options:(NSDirectoryEnumerationOptions)mask
                       withReply:(void (^)(NSError*,NSArray<NSURL*>*))reply
{
    NSError *error = nil;
    NSArray<NSURL*> *contents = [_fileManager contentsOfDirectoryAtURL:url includingPropertiesForKeys:keys options:mask error:&error];
    reply(error,contents);
}

- (void)subpathsOfDirectoryAtPath:(NSString *)path
                        withReply:(void (^)(NSError*,NSArray<NSString*>*))reply
{
    NSError *error = nil;
    NSArray<NSString*> *subpaths = [_fileManager subpathsOfDirectoryAtPath:path error:&error];
    reply(error,subpaths);
}

- (void)createDirectoryAtURL:(NSURL *)url
 withIntermediateDirectories:(BOOL)createIntermediates
                  attributes:(nullable NSDictionary<NSFileAttributeKey, id> *)attributes
                   withReply:(void (^)(NSError*,BOOL))reply
{
    NSError *error = nil;
    BOOL success = [_fileManager createDirectoryAtURL:url withIntermediateDirectories:createIntermediates attributes:attributes error:&error];
    reply(error,success);
}

- (void)createFileAtPath:(NSString *)path
                contents:(nullable NSData *)data
              attributes:(nullable NSDictionary<NSFileAttributeKey, id> *)attr
               withReply:(void (^)(BOOL))reply
{
    reply([_fileManager createFileAtPath:path contents:data attributes:attr]);
}

- (void)createSymbolicLinkAtURL:(NSURL *)url
             withDestinationURL:(NSURL *)destURL
                      withReply:(void (^)(NSError*,BOOL))reply
{
    NSError *error = nil;
    BOOL success = [_fileManager createSymbolicLinkAtURL:url withDestinationURL:destURL error:&error];
    reply(error,success);
}

- (void)destinationOfSymbolicLinkAtPath:(NSString *)path
                              withReply:(void (^)(NSError*,NSString*))reply
{
    NSError *error = nil;
    NSString *dest = [_fileManager destinationOfSymbolicLinkAtPath:path error:&error];
    reply(error,dest);
}

- (void)attributesOfItemAtPath:(NSString *)path
                     withReply:(void (^)(NSError*,NSDictionary<NSFileAttributeKey, id> *))reply
{
    NSError *error = nil;
    NSDictionary<NSFileAttributeKey, id> *attr = [_fileManager attributesOfItemAtPath:path error:&error];
    reply(error,attr);
}

- (void)setAttributes:(NSDictionary<NSFileAttributeKey, id> *)attributes
         ofItemAtPath:(NSString *)path
            withReply:(void (^)(NSError*,BOOL))reply
{
    NSError *error = nil;
    BOOL success = [_fileManager setAttributes:attributes ofItemAtPath:path error:&error];
    reply(error,success);
}

- (void)copyItemAtURL:(NSURL *)srcURL
                toURL:(NSURL *)dstURL
            withReply:(void (^)(NSError*,BOOL))reply
{
    NSError *error = nil;
    BOOL success = [_fileManager copyItemAtURL:srcURL toURL:dstURL error:&error];
    reply(error,success);
}

- (void)moveItemAtURL:(NSURL *)srcURL
                toURL:(NSURL *)dstURL
            withReply:(void (^)(NSError*,BOOL))reply
{
    NSError *error = nil;
    BOOL success = [_fileManager moveItemAtURL:srcURL toURL:dstURL error:&error];
    reply(error,success);
}

- (void)linkItemAtURL:(NSURL *)srcURL
                toURL:(NSURL *)dstURL
            withReply:(void (^)(NSError*,BOOL))reply
{
    NSError *error = nil;
    BOOL success = [_fileManager linkItemAtURL:srcURL toURL:dstURL error:&error];
    reply(error,success);
}

- (void)removeItemAtURL:(NSURL *)URL
              withReply:(void (^)(NSError*,BOOL))reply
{
    NSError *error = nil;
    BOOL success = [_fileManager removeItemAtURL:URL error:&error];
    reply(error,success);
}

- (void)fileExistsAtPath:(NSString *)path
               withReply:(void (^)(BOOL isDirectory,BOOL exists))reply
{
    BOOL isDirectory = NO;
    BOOL exists = [_fileManager fileExistsAtPath:path isDirectory:&isDirectory];
    reply(isDirectory,exists);
}

- (void)isReadableFileAtPath:(NSString *)path
                   withReply:(void (^)(BOOL))reply
{
    reply([_fileManager isReadableFileAtPath:path]);
}

- (void)isWritableFileAtPath:(NSString *)path
                   withReply:(void (^)(BOOL))reply
{
    reply([_fileManager isWritableFileAtPath:path]);
}

- (void)isExecutableFileAtPath:(NSString *)path
                     withReply:(void (^)(BOOL))reply
{
    reply([_fileManager isExecutableFileAtPath:path]);
}

- (void)isDeletableFileAtPath:(NSString *)path
                    withReply:(void (^)(BOOL))reply
{
    reply([_fileManager isDeletableFileAtPath:path]);
}

- (void)contentsAtPath:(NSString *)path
             withReply:(void (^)(NSData *))reply
{
    reply([_fileManager contentsAtPath:path]);
}

- (void)contentsEqualAtPath:(NSString *)path1
                    andPath:(NSString *)path2
                  withReply:(void (^)(BOOL))reply
{
    reply([_fileManager contentsEqualAtPath:path1 andPath:path2]);
}

- (void)fdObjectForItemAtPath:(NSString *)path
                    withFlags:(int)flags
                     withMode:(mode_t)mode
                    withReply:(void (^)(FDObject*))reply
{
    reply([FDObject objectForFileAtPath:path withFlags:flags withPermissions:mode]);
}

- (void)containerRootWithReply:(void (^)(NSURL*))reply
{
    reply([NSURL fileURLWithPath:NSHomeDirectory()]);
}

- (void)containerHomeWithReply:(void (^)(NSURL*))reply
{
    reply([[NSURL fileURLWithPath:NSHomeDirectory()] URLByAppendingPathExtension:@"Documents"]);
}

@end
