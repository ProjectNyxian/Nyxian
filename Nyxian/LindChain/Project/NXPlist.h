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

#ifndef NXPLISTHELPER_H
#define NXPLISTHELPER_H

#import <Foundation/Foundation.h>

@interface NXPlist : NSObject

@property (nonatomic,strong,readonly,nonnull) NSString *plistPath;
@property (nonatomic,strong,readwrite,nonnull) NSDictionary<NSString*,NSString*> *variables;
@property (nonatomic,strong,readwrite,nonnull) NSMutableDictionary * dictionary;
@property (nonatomic,strong,readonly,nullable) NSString *dataHash;

- (instancetype _Nullable)initWithPlistPath:(NSString * _Nonnull)plistPath withVariables:(NSDictionary<NSString*,NSString*> * _Nullable)variables;

- (BOOL)reloadIfNeeded;
- (void)reloadData;
- (BOOL)save;

- (id _Nullable)objectForKey:(NSString * _Nonnull)key;
- (id _Nonnull)objectForKey:(NSString * _Nonnull)key withDefaultObject:(id _Nonnull)value;
- (id _Nullable)objectForKey:(NSString * _Nonnull)key withClass:(Class _Nonnull)cls;

- (NSInteger)integerForKey:(NSString * _Nonnull)key withDefaultValue:(NSInteger)defaultValue;
- (BOOL)booleanForKey:(NSString * _Nonnull)key withDefaultValue:(BOOL)defaultValue;
- (double)doubleForKey:(NSString * _Nonnull)key withDefaultValue:(double)defaultValue;

@end

#endif /* NXPLISTHELPER_H */
