/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2025 - 2026 emexlab

 This file is part of Nyxian.

 Licensed under the emexLabs Public Source License, version 1.1
 (EPSL 1.1).

 Private use and modification are permitted under the license.
 Redistribution of source or binaries, modified or unmodified,
 requires prior written permission from emexLabs.

 External deployment is subject to the source-availability
 requirements and other conditions of the license.

 Provided "AS IS", without warranty, to the extent permitted by law.

 See LICENSE for the full license terms.
*/

#ifndef NXPLISTHELPER_H
#define NXPLISTHELPER_H

#import <Foundation/Foundation.h>

@interface NSDictionary (Nyxian)

@property (nonatomic,strong,nullable) NSDictionary *variables;

- (id _Nonnull)expandString:(NSString * _Nonnull)input depth:(int)depth ownRoot:(NSDictionary * _Nullable)oroot;
- (id _Nonnull)expandObject:(id _Nonnull)obj ownRoot:(NSDictionary * _Nullable)oroot;

- (id _Nullable)varObjectForKey:(id _Nonnull)aKey;
- (id _Nonnull)objectForKey:(NSString * _Nonnull)key withDefaultObject:(id _Nonnull)value;
- (id _Nullable)objectForKey:(NSString * _Nonnull)key withClass:(Class _Nonnull)cls;

- (NSArray * _Nonnull)arrayForKey:(NSString * _Nonnull)key allowedTypes:(NSSet<Class> * _Nonnull)allowedTypes;

- (NSInteger)integerForKey:(NSString * _Nonnull)key withDefaultValue:(NSInteger)defaultValue;
- (BOOL)booleanForKey:(NSString * _Nonnull)key withDefaultValue:(BOOL)defaultValue;
- (double)doubleForKey:(NSString * _Nonnull)key withDefaultValue:(double)defaultValue;

@end

@interface NSMutableDictionary (Nyxian)

- (void)remapKey:(NSString * _Nonnull)oldKey toKey:(NSString * _Nonnull)newKey withRemapHandler:(id _Nonnull (^ _Nullable)(id _Nonnull oldObj))handler;
- (void)remapKey:(NSString * _Nonnull)oldKey toKey:(NSString * _Nonnull)newKey;

@end

@interface NXPlist : NSObject

@property (nonatomic,strong,readonly,nonnull) NSString *plistPath;
@property (nonatomic,strong,readwrite,nonnull) NSDictionary<NSString*,NSString*> *variables;
@property (atomic,strong,readonly,nonnull) NSDictionary *originalDictionary;
@property (atomic,strong,readwrite,nonnull) NSMutableDictionary *dictionary;
@property (atomic,strong,readonly,nullable) NSString *dataHash;

- (instancetype _Nullable)initWithPlistPath:(NSString * _Nonnull)plistPath withVariables:(NSDictionary<NSString*,NSString*> * _Nullable)variables;

- (BOOL)reloadIfNeeded;
- (void)reloadData;
- (BOOL)save;

@end

#endif /* NXPLISTHELPER_H */
