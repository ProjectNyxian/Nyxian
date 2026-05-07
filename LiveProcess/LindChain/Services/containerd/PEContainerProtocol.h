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

#ifndef PECONTAINERPROTOCOL_H
#define PECONTAINERPROTOCOL_H

#import <Foundation/Foundation.h>
#import <LindChain/ProcEnvironment/Object/FDObject.h>

NS_HEADER_AUDIT_BEGIN(nullability, sendability)

@protocol PEContainerProtocol <NSObject>

- (void)contentsOfDirectoryAtURL:(NSURL *)url includingPropertiesForKeys:(nullable NSArray<NSURLResourceKey> *)keys options:(NSDirectoryEnumerationOptions)mask withReply:(void (^)(NSError*,NSArray<NSURL*>*))reply;
- (void)subpathsOfDirectoryAtPath:(NSString *)path withReply:(void (^)(NSError*,NSArray<NSString*>*))reply;

- (void)createDirectoryAtURL:(NSURL *)url withIntermediateDirectories:(BOOL)createIntermediates attributes:(nullable NSDictionary<NSFileAttributeKey, id> *)attributes withReply:(void (^)(NSError*,BOOL))reply;
- (void)createFileAtPath:(NSString *)path contents:(nullable NSData *)data attributes:(nullable NSDictionary<NSFileAttributeKey, id> *)attr withReply:(void (^)(BOOL))reply;
- (void)createSymbolicLinkAtURL:(NSURL *)url withDestinationURL:(NSURL *)destURL withReply:(void (^)(NSError*,BOOL))reply;
- (void)destinationOfSymbolicLinkAtPath:(NSString *)path withReply:(void (^)(NSError*,NSString*))reply;

- (void)attributesOfItemAtPath:(NSString *)path withReply:(void (^)(NSError*,NSDictionary<NSFileAttributeKey, id> *))reply;
- (void)setAttributes:(NSDictionary<NSFileAttributeKey, id> *)attributes ofItemAtPath:(NSString *)path withReply:(void (^)(NSError*,BOOL))reply;

- (void)copyItemAtURL:(NSURL *)srcURL toURL:(NSURL *)dstURL withReply:(void (^)(NSError*,BOOL))reply;
- (void)moveItemAtURL:(NSURL *)srcURL toURL:(NSURL *)dstURL withReply:(void (^)(NSError*,BOOL))reply;
- (void)linkItemAtURL:(NSURL *)srcURL toURL:(NSURL *)dstURL withReply:(void (^)(NSError*,BOOL))reply;
- (void)removeItemAtURL:(NSURL *)URL withReply:(void (^)(NSError*,BOOL))reply;

- (void)fileExistsAtPath:(NSString *)path withReply:(void (^)(BOOL isDirectory,BOOL exists))reply;
- (void)isReadableFileAtPath:(NSString *)path withReply:(void (^)(BOOL))reply;
- (void)isWritableFileAtPath:(NSString *)path withReply:(void (^)(BOOL))reply;
- (void)isExecutableFileAtPath:(NSString *)path withReply:(void (^)(BOOL))reply;
- (void)isDeletableFileAtPath:(NSString *)path withReply:(void (^)(BOOL))reply;

- (void)contentsAtPath:(NSString *)path withReply:(void (^)(NSData *))reply;
- (void)contentsEqualAtPath:(NSString *)path1 andPath:(NSString *)path2 withReply:(void (^)(BOOL))reply;

- (void)fdObjectForItemAtPath:(NSString *)path withFlags:(int)flags withMode:(mode_t)mode  withReply:(void (^)(FDObject*))reply;

- (void)containerRootWithReply:(void (^)(NSURL*))reply;
- (void)containerHomeWithReply:(void (^)(NSURL*))reply;

@end

NS_HEADER_AUDIT_END(nullability, sendability)

#endif /* PECONTAINERPROTOCOL_H */
