/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 cr4zyengineer

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

#import <LindChain/Project/NXPlist.h>
#import <CommonCrypto/CommonDigest.h>
#import <os/lock.h>

@implementation NXPlist {
    os_unfair_lock _lock;
    __strong NSString *_savedHash;
}

- (instancetype)initWithPlistPath:(NSString * _Nonnull)plistPath
                    withVariables:(NSDictionary<NSString*,NSString*> * _Nullable)variables
{
    if(variables == nil)
    {
        variables = @{};
    }
    
    self = [super init];
    if(self)
    {
        _lock = OS_UNFAIR_LOCK_INIT;
        _plistPath = plistPath;
        _savedHash = [self currentHash];
        _variables = variables;
        [self reloadData];
    }
    return self;
}

- (NSString *)currentHash
{
    NSData *fileData = [NSData dataWithContentsOfFile:_plistPath];
    if (!fileData) return nil;

    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(fileData.bytes, (CC_LONG)fileData.length, hash);

    NSMutableString *hashString = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
        [hashString appendFormat:@"%02x", hash[i]];
    }
    return hashString;
}

- (BOOL)reloadIfNeeded
{
    NSString *hash = [self currentHash];
    
    [self willChangeValueForKey:@"dictionary"];
    
    os_unfair_lock_lock(&_lock);
    BOOL needsReload = ![hash isEqualToString:_savedHash];
    if(needsReload)
    {
        _dictionary = [[NSMutableDictionary alloc] initWithContentsOfFile:_plistPath];
        _savedHash = hash;
        
        NSDictionary<NSString*,NSString*> *userDef = _dictionary;
        
        if(userDef && [userDef isKindOfClass:[NSDictionary class]])
        {
            NSMutableDictionary<NSString*,NSString*> *finalDef = [self.variables mutableCopy];
            
            for(NSString *key in userDef)
            {
                NSString *value = userDef[key];
                if([value isKindOfClass:[NSString class]])
                {
                    [finalDef setObject:(NSString*)value forKey:key];
                }
            }
            
            _finalVariables = [finalDef copy];
        }
        else
        {
            _finalVariables = _variables;
        }
    }
    os_unfair_lock_unlock(&_lock);
    
    [self didChangeValueForKey:@"dictionary"];
    
    return needsReload;
}

- (void)reloadData
{
    _savedHash = @"";
    [self reloadIfNeeded];
}

- (NSString*)reloadHash
{
    return _savedHash;
}

- (BOOL)save
{
    os_unfair_lock_lock(&_lock);
    [self.dictionary writeToFile:self.plistPath atomically:YES];
    os_unfair_lock_unlock(&_lock);
    return [self reloadIfNeeded];
}

- (BOOL)reloadIfNeededWithHash:(NSString*)reloadHash
{
    if([[self currentHash] isEqualToString:reloadHash])
    {
        return NO;
    }
    
    [self reloadIfNeeded];
    return YES;
}

- (NSString * _Nonnull)expandString:(NSString * _Nonnull)input depth:(int)depth
{
    if(!input || depth > 10) return input;
    
    NSMutableString *result = [input mutableCopy];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\$\\(([^\\)]+)\\)" options:0 error:nil];
    NSArray<NSTextCheckingResult*> *matches = [regex matchesInString:result options:0 range:NSMakeRange(0, result.length)];
    
    for(NSTextCheckingResult *match in [matches reverseObjectEnumerator])
    {
        NSRange varRange = [match rangeAtIndex:1];
        NSString *varName = [result substringWithRange:varRange];
        
        NSString *value = self.finalVariables[varName];
        if(!value)
        {
            value = NSProcessInfo.processInfo.environment[varName];
        }
        
        if(value)
        {
            value = [self expandString:value depth:depth + 1];
            [result replaceCharactersInRange:match.range withString:value];
        }
    }
    
    return result;
    return NULL;
}

- (id _Nonnull)expandObject:(id _Nonnull)obj
{
    if([obj isKindOfClass:NSString.class])
    {
        return [self expandString:obj depth:0];
    }
    
    if([obj isKindOfClass:NSArray.class])
    {
        NSMutableArray *arr = [NSMutableArray array];
        for(id v in (NSArray*)obj)
        {
            [arr addObject:[self expandObject:v]];
        }
        return arr;
    }
    
    if([obj isKindOfClass:NSDictionary.class])
    {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        for(id key in (NSDictionary*)obj)
        {
            dict[key] = [self expandObject:obj[key]];
        }
        return dict;
    }
    
    return obj;
}

- (id)objectForKey:(NSString*)key
{
    os_unfair_lock_lock(&_lock);
    id obj = [_dictionary objectForKey:key];
    if(obj == nil)
    {
        os_unfair_lock_unlock(&_lock);
        return nil;
    }
    obj = [self expandObject:obj];
    os_unfair_lock_unlock(&_lock);
    return obj;
}

- (id)objectForKey:(NSString*)key
 withDefaultObject:(id)value
{
    /*
     * we have to check if its the same type
     * as the default type, that is the upgrade
     * to prior method signature were you needed
     * the class type aswell, now you can pass
     * the class type using the default value
     * if you want a nullable
     */
    id valueOfKey = [self objectForKey:key];
    if(!valueOfKey && ![valueOfKey isKindOfClass:[value class]])
    {
        return value;
    }
    
    /*
     * if everything matches up, we can safely
     * return this.
     */
    return valueOfKey;
}

- (id)objectForKey:(NSString * _Nonnull)key
         withClass:(Class _Nonnull)cls
{
    /*
     * this method is a bit different, it makes
     * the return value nullable, as there is no
     * defaultObject.
     */
    id valueOfKey = [self objectForKey:key];
    if(!valueOfKey && ![valueOfKey isKindOfClass:cls])
    {
        /* god damn */
        return nil;
    }
    
    /*
     * if everything matches up, we can safely
     * return this.
     */
    return valueOfKey;
}

- (NSInteger)integerForKey:(NSString *)key
          withDefaultValue:(NSInteger)defaultValue
{
    return [[self objectForKey:key withDefaultObject:@(defaultValue)] integerValue];
}

- (BOOL)booleanForKey:(NSString *)key
     withDefaultValue:(BOOL)defaultValue
{
    return [[self objectForKey:key withDefaultObject:@(defaultValue)] boolValue];
}

- (double)doubleForKey:(NSString *)key
      withDefaultValue:(double)defaultValue
{
    return [[self objectForKey:key withDefaultObject:@(defaultValue)] doubleValue];
}

@end
