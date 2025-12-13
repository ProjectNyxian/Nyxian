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

#import <Foundation/Foundation.h>

@interface NXPlistHelper : NSObject

@property (nonatomic,strong,readonly) NSString * _Nonnull plistPath;
@property (nonatomic,strong,readwrite)  NSMutableDictionary * _Nonnull dictionary;

- (instancetype _Nonnull)initWithPlistPath:(NSString * _Nonnull)plistPath;
- (BOOL)reloadIfNeeded;
- (void)reloadData;
- (void)writeKey:(NSString * _Nonnull)key withValue:(id _Nonnull)value;
- (id _Nonnull)readKey:(NSString * _Nonnull)key;
- (id _Nonnull)readSecureFromKey:(NSString * _Nonnull)key withDefaultValue:(id _Nonnull)value classType:Class;
- (NSString * _Nonnull)readStringForKey:(NSString * _Nonnull)key withDefaultValue:(NSString * _Nonnull)defaultValue;
- (NSNumber * _Nonnull)readNumberForKey:(NSString * _Nonnull)key withDefaultValue:(NSNumber * _Nonnull)defaultValue;
- (NSInteger)readIntegerForKey:(NSString * _Nonnull)key withDefaultValue:(NSInteger)defaultValue;
- (BOOL)readBooleanForKey:(NSString * _Nonnull)key withDefaultValue:(BOOL)defaultValue;
- (double)readDoubleForKey:(NSString * _Nonnull)key withDefaultValue:(double)defaultValue;
- (NSArray * _Nonnull)readArrayForKey:(NSString * _Nonnull)key withDefaultValue:(NSArray * _Nonnull)defaultValue;

@end
