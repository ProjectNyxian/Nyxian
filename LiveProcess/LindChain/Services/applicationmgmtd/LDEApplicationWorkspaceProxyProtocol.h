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

#ifndef LDEAPPLICATIONWORKSPACEPROXYPROTOCOL_H
#define LDEAPPLICATIONWORKSPACEPROXYPROTOCOL_H

#import <Foundation/Foundation.h>
#import <LindChain/ProcEnvironment/Object/ArchiveObject.h>

@protocol LDEApplicationWorkspaceProxyProtocol

- (void)ping;
- (void)installApplicationWithArchiveObject:(ArchiveObject*)archiveObject withReply:(void (^)(BOOL))reply;
- (void)deleteApplicationWithBundleID:(NSString*)bundleID withReply:(void (^)(BOOL))reply;
- (void)applicationInstalledWithBundleID:(NSString*)bundleID withReply:(void (^)(BOOL))reply;
- (void)applicationObjectForBundleID:(NSString*)bundleID withReply:(void (^)(LDEApplicationObject*))reply;
- (void)applicationContainerForBundleID:(NSString*)bundleID withReply:(void (^)(NSURL*))reply;
- (void)allApplicationObjectsWithReply:(void (^)(LDEApplicationObjectArray *))reply;
- (void)clearContainerForBundleID:(NSString*)bundleID withReply:(void (^)(BOOL))reply;
- (void)fastpathUtility:(FileObject*)object withReply:(void (^)(NSString*,BOOL))reply;
- (void)applicationObjectForExecutablePath:(NSString*)executablePath withReply:(void (^)(LDEApplicationObject*))reply;

@end

#endif /* LDEAPPLICATIONWORKSPACEPROXYPROTOCOL_H */
