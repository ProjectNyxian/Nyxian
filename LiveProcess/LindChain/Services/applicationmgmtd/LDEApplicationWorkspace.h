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

#ifndef LDEAPPLICATIONWORKSPACEPROXY_H
#define LDEAPPLICATIONWORKSPACEPROXY_H

#import <Foundation/Foundation.h>
#import <LindChain/Services/applicationmgmtd/LDEApplicationWorkspaceProtocol.h>
#import "LDEApplicationObject.h"
#import "LDEApplicationWorkspaceProxyProtocol.h"

@interface LDEApplicationWorkspace : NSObject <LDEApplicationWorkspaceProtocol>

@property (nonatomic,strong) NSXPCConnection *connection;

- (instancetype)init;
+ (instancetype)shared;

- (void)ping;
- (BOOL)installApplicationAtBundlePath:(NSString*)bundlePath;
- (BOOL)installApplicationAtPackagePath:(NSString*)packagePath;
- (BOOL)deleteApplicationWithBundleID:(NSString*)bundleID;
- (BOOL)applicationInstalledWithBundleID:(NSString*)bundleID;
- (LDEApplicationObject*)applicationObjectForBundleID:(NSString*)bundleID;
- (NSArray<LDEApplicationObject*>*)allApplicationObjects;
- (BOOL)clearContainerForBundleID:(NSString*)bundleID;
- (NSString*)fastpathUtility:(NSString*)utilityPath;
- (LDEApplicationObject*)applicationObjectForExecutablePath:(NSString*)executablePath;
- (BOOL)openApplicationWithBundleIdentifier:(NSString*)bundleIdentifier;

@end

#endif /* LDEAPPLICATIONWORKSPACEPROXY_H */
