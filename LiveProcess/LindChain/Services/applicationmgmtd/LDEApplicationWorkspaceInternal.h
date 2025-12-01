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

#ifndef LDEAPPLICATIONWORKSPACE_H
#define LDEAPPLICATIONWORKSPACE_H

#import <Foundation/Foundation.h>
#import <ServiceKit/ServiceKit.h>
#import "LDEApplicationObject.h"
#import "LDEApplicationWorkspaceProxyProtocol.h"
#import "MIBundle.h"

@interface LDEApplicationWorkspaceInternal : NSObject

@property (atomic,readwrite) NSMutableDictionary<NSString*,MIExecutableBundle*> *bundles;

- (instancetype)init;
+ (LDEApplicationWorkspaceInternal*)shared;

- (BOOL)installApplicationWithPayloadPath:(NSString*)bundlePath;
- (BOOL)deleteApplicationWithBundleID:(NSString*)bundleID;
- (BOOL)applicationInstalledWithBundleID:(NSString*)bundleID;
- (MIBundle*)applicationBundleForBundleID:(NSString*)bundleID;
- (NSURL*)applicationContainerForBundleID:(NSString *)bundleID;
- (BOOL)doWeTrustThatBundle:(MIExecutableBundle*)bundle;
- (BOOL)clearContainerForBundleID:(NSString*)bundleID;

@end

@interface LDEApplicationWorkspaceProxy : NSObject <LDEApplicationWorkspaceProxyProtocol,LDEServiceProtocol>
@end

#endif /* LDEAPPLICATIONWORKSPACE_H */
