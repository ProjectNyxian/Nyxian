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

#ifndef NXTARGET_H
#define NXTARGET_H

#import <Foundation/Foundation.h>
#import <LindChain/Project/NXType.h>
#import <LindChain/Project/NXUser.h>
#import <LindChain/Project/NXPlist.h>

@interface NXTarget : NSObject

@property (nonatomic, strong, readonly, nonnull) NSString *displayName;

@property (nonatomic, strong, readonly, nonnull) NSString *bundleName;
@property (nonatomic, strong, readonly, nonnull) NSString *bundleIdentifier;
@property (nonatomic, strong, readonly, nonnull) NSArray<NSURL*> *bundleResourceURLs;

@property (nonatomic, readonly) NXProjectSchemeKind schemeKind;

@property (nonatomic, strong, readonly, nonnull) NSString *deploymentTarget;

@property (nonatomic, strong, readonly, nonnull) NSURL *sdkURL;
@property (nonatomic, strong, readonly, nonnull) NSArray<NSURL*> *sourceURLs;
@property (nonatomic, strong, readonly, nonnull) NSArray<NSURL*> *headerSearchURLs;
@property (nonatomic, strong, readonly, nonnull) NSArray<NSURL*> *frameworkSearchURLs;
@property (nonatomic, strong, readonly, nonnull) NSArray<NSURL*> *librarySearchURLs;

@property (nonatomic, strong, readonly, nonnull) NSArray<NSString*> *otherClangFlags;
@property (nonatomic, strong, readonly, nonnull) NSArray<NSString*> *otherSwiftFlags;
@property (nonatomic, strong, readonly, nonnull) NSArray<NSString*> *otherLinkerFlags;

@property (nonatomic, strong, readonly, nonnull) NSArray<NSString*> *frameworks;
@property (nonatomic, strong, readonly, nonnull) NSArray<NSString*> *libraries;
@property (nonatomic, strong, readonly, nonnull) NSArray<NSString*> *dependentTargets;

+ (instancetype _Nullable)targetWithDictionary:(NSDictionary * _Nonnull)dictionary;

- (instancetype _Nullable)initWithDictionary:(NSDictionary * _Nonnull)dictionary;

@end

#endif /* NXTARGET_H */
