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

#import <LindChain/Project/NXPlist.h>
#import <CommonCrypto/CommonDigest.h>
#import <os/lock.h>
#import <objc/runtime.h>
#import <LindChain/Utils/Swizzle.h>

static const char kNSDictionaryVariables;

@implementation NSDictionary (Nyxian)

- (NSDictionary*)variables
{
    return objc_getAssociatedObject(self, &kNSDictionaryVariables);
}

- (void)setVariables:(NSDictionary*)variables
{
    objc_setAssociatedObject(self, &kNSDictionaryVariables, variables, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (id)expandString:(NSString*)input
             depth:(int)depth
           ownRoot:(NSDictionary*)oroot
{
    oroot = oroot?: self;
    
    if(!input || depth > 10) return input;
    
    NSMutableString *result = [input mutableCopy];
    NSRegularExpression *regex = [NSRegularExpression regularExpressionWithPattern:@"\\$\\(([^\\)]+)\\)" options:0 error:nil];
    NSArray<NSTextCheckingResult*> *matches = [regex matchesInString:result options:0 range:NSMakeRange(0, result.length)];
    
    for(NSTextCheckingResult *match in [matches reverseObjectEnumerator])
    {
        NSRange varRange = [match rangeAtIndex:1];
        NSString *varName = [result substringWithRange:varRange];
        NSArray<NSString*> *varPathComponents = [varName componentsSeparatedByString:@"."];
        
        /*
         * find the object root in root, if not
         * then fallback to self as root.
         */
        id sroot = oroot;
        id currentObject = nil;
        BOOL success = YES;
        for(NSString *component in varPathComponents)
        {
            if(currentObject == nil)
            {
                /*
                 * means its root, cuz there
                 * is no current object
                 */
                currentObject = sroot[component];
                continue;
            }
            
            /* if its not a dictionary its fake */
            if(![currentObject isKindOfClass:[NSDictionary class]])
            {
                success = NO;
                break;
            }
            
            NSDictionary *sroot = currentObject;
            currentObject = sroot[component];
        }
        
        if(!success)
        {
            sroot = self;
            for(NSString *component in varPathComponents)
            {
                if(currentObject == nil)
                {
                    /*
                     * means its root, cuz there
                     * is no current object
                     */
                    currentObject = sroot[component];
                    continue;
                }
                
                /* if its not a dictionary its fake */
                if(![currentObject isKindOfClass:[NSDictionary class]])
                {
                    success = NO;
                    break;
                }
                
                NSDictionary *sroot = currentObject;
                currentObject = sroot[component];
            }
        }
        
        /* either blank it out or nah */
        NSString *replacementValue = nil;
        if(success && [currentObject isKindOfClass:[NSString class]])
        {
            replacementValue = [self expandString:currentObject depth:depth + 1 ownRoot:sroot];
        }
        else
        {
            replacementValue = self.variables[varName];
            if(!replacementValue)
            {
                replacementValue = NSProcessInfo.processInfo.environment[varName];
            }
        }
        
        replacementValue = replacementValue?: @"";
        
        [result replaceCharactersInRange:match.range withString:replacementValue];
        
        /*NSString *value = _finalVariables[varName];
        if(!value)
        {
            value = NSProcessInfo.processInfo.environment[varName];
        }*/
        
        /*if(replacementValue)
        {
            value = [self expandString:value depth:depth + 1];
            [result replaceCharactersInRange:match.range withString:value];
        }*/
    }
    
    return result;
    return NULL;
}

- (id)expandObject:(id)obj
           ownRoot:(NSDictionary*)oroot
{
    oroot = oroot?: self;
    
    if([obj isKindOfClass:NSString.class])
    {
        return [self expandString:obj depth:0 ownRoot:oroot];
    }
    
    if([obj isKindOfClass:NSArray.class])
    {
        NSMutableArray *arr = [NSMutableArray array];
        for(id v in (NSArray*)obj)
        {
            [arr addObject:[self expandObject:v ownRoot:oroot]];
        }
        return arr;
    }
    
    if([obj isKindOfClass:NSDictionary.class])
    {
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        for(id key in (NSDictionary*)obj)
        {
            dict[key] = [self expandObject:obj[key] ownRoot:oroot];
        }
        return dict;
    }
    
    return obj;
}

- (id)varObjectForKey:(id)aKey
{
    id obj = [self objectForKey:aKey];
    if(obj == nil)
    {
        return nil;
    }
    return [self expandObject:obj ownRoot:self];
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
    id valueOfKey = [self varObjectForKey:key];
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

- (NSArray*)arrayForKey:(NSString *)key
           allowedTypes:(NSSet<Class> *)allowedTypes
{
    NSArray *array = [self objectForKey:key withDefaultObject:@[]];
    NSMutableArray *resultArray = [NSMutableArray array];
    
    /* iteratting through array */
    for(id obj in array)
    {
        /* skip if type is not allowed */
        BOOL pass = NO;
        for(Class cls in allowedTypes)
        {
            if([obj isKindOfClass:cls])
            {
                pass = YES;
                break;
            }
        }
        
        if(!pass)
        {
            continue;
        }
        
        [resultArray addObject:obj];
    }
    
    return [resultArray copy];
}

- (id)objectForKey:(NSString*)key
         withClass:(Class)cls
{
    /*
     * this method is a bit different, it makes
     * the return value nullable, as there is no
     * defaultObject.
     */
    id valueOfKey = [self varObjectForKey:key];
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

- (NSInteger)integerForKey:(NSString*)key
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

@implementation NXPlist {
    os_unfair_lock _lock;
}

- (instancetype)initWithPlistPath:(NSString * _Nonnull)plistPath
                    withVariables:(NSDictionary<NSString*,NSString*> * _Nullable)variables
{
    self = [super init];
    if(self)
    {
        _lock = OS_UNFAIR_LOCK_INIT;
        _plistPath = plistPath;
        _dataHash = [self currentHash];
        _variables = variables?: @{};
        [self reloadData];
    }
    return self;
}

- (NSString *)currentHash
{
    NSData *fileData = [NSData dataWithContentsOfFile:_plistPath];
    if(fileData == nil)
    {
        return nil;
    }

    unsigned char hash[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(fileData.bytes, (CC_LONG)fileData.length, hash);

    NSMutableString *hashString = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
    for(int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++)
    {
        [hashString appendFormat:@"%02x", hash[i]];
    }
    return hashString;
}

- (BOOL)reloadIfNeeded
{
    NSString *hash = [self currentHash];
    
    [self willChangeValueForKey:@"dictionary"];
    
    os_unfair_lock_lock(&_lock);
    BOOL needsReload = ![hash isEqualToString:_dataHash];
    if(needsReload)
    {
        _originalDictionary = [NSDictionary dictionaryWithContentsOfFile:_plistPath];
        _dictionary = [_originalDictionary mutableCopy];
        _dataHash = hash;
        _dictionary.variables = self.variables;
    }
    os_unfair_lock_unlock(&_lock);
    
    [self didChangeValueForKey:@"dictionary"];
    
    return needsReload;
}

- (void)reloadData
{
    _dataHash = nil;
    [self reloadIfNeeded];
}

- (BOOL)save
{
    os_unfair_lock_lock(&_lock);
    [self.dictionary writeToFile:self.plistPath atomically:YES];
    os_unfair_lock_unlock(&_lock);
    return [self reloadIfNeeded];
}

- (void)remapKey:(NSString*)oldKey
           toKey:(NSString*)newKey
withRemapHandler:(id (^)(id oldObj))handler
{
    /* remapping old keynames to new ones to create a kind of compatibility layer  */
    id newObj = [self.dictionary objectForKey:newKey];
    if(newObj == nil)
    {
        id oldObj = [self.dictionary objectForKey:oldKey];
        if(oldObj != nil)
        {
            /*
             * letting caller patch the old object,
             * to for example convert it into something
             * else.
             */
            if(handler != nil)
            {
                oldObj = handler(oldObj);
                
                if(oldObj == nil)
                {
                    return;
                }
            }
            
            [self.dictionary setObject:oldObj forKey:newKey];
            [self.dictionary removeObjectForKey:oldKey];
            
            /*
             * create a fake variable remap so
             * that if the users defined flags
             * use for example $(LDEMinimumVersion)
             * they straightup point back to the new one.
             */
            NSMutableDictionary<NSString*,NSString*> *variables = [self.variables mutableCopy];
            [variables setObject:[NSString stringWithFormat:@"$(%@)", newKey] forKey:oldKey];
            self.variables = [variables copy];
        }
    }
}

- (void)remapKey:(NSString*)oldKey
           toKey:(NSString*)newKey
{
    [self remapKey:oldKey toKey:newKey withRemapHandler:nil];
}

@end
