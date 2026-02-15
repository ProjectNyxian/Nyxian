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

#import <LindChain/Project/NXPlistHelper.h>
#import <CommonCrypto/CommonDigest.h>

@interface NXPlistHelper ()

@property (nonatomic,strong,readwrite) NSString *savedHash;

@end

@implementation NXPlistHelper

- (instancetype _Nonnull)initWithPlistPath:(NSString * _Nonnull)plistPath
                             withVariables:(NSDictionary<NSString*,NSString*> * _Nonnull)variables
{
    self = [super init];
    _plistPath = plistPath;
    _savedHash = [self currentHash];
    _variables = variables;
    [self reloadData];
    return self;
}

- (instancetype)initWithPlistPath:(NSString*)plistPath
{
    return [self initWithPlistPath:plistPath withVariables:@{}];
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
    return needsReload;
}

- (void)reloadData
{
    _savedHash = @"";
    [self reloadIfNeeded];
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

- (void)writeKey:(NSString*)key
       withValue:(id)value
{
    [_dictionary setObject:value forKey:key];
    [_dictionary writeToFile:_plistPath atomically:YES];
    _savedHash = [self currentHash];
}

- (id)readKey:(NSString*)key
{
    return [self expandObject:[_dictionary objectForKey:key]];
}

- (id)readSecureFromKey:(NSString*)key
       withDefaultValue:(id)value
              classType:Class
{
    id valueOfKey = [self readKey:key];
    if(!valueOfKey && ![valueOfKey isKindOfClass:Class])
    {
        valueOfKey = value;
    }
    return valueOfKey;
}

- (NSString *)readStringForKey:(NSString *)key
              withDefaultValue:(NSString *)defaultValue
{
    return [self readSecureFromKey:key withDefaultValue:defaultValue classType:[NSString class]];
}

- (NSNumber*)readNumberForKey:(NSString *)key
             withDefaultValue:(NSNumber *)defaultValue
{
    return [self readSecureFromKey:key withDefaultValue:defaultValue classType:[NSNumber class]];
}

- (NSInteger)readIntegerForKey:(NSString *)key
              withDefaultValue:(NSInteger)defaultValue
{
    return [[self readNumberForKey:key withDefaultValue:@(defaultValue)] integerValue];
}

- (BOOL)readBooleanForKey:(NSString *)key
         withDefaultValue:(BOOL)defaultValue
{
    return [[self readNumberForKey:key withDefaultValue:@(defaultValue)] boolValue];
}

- (double)readDoubleForKey:(NSString *)key
          withDefaultValue:(double)defaultValue
{
    return [[self readNumberForKey:key withDefaultValue:@(defaultValue)] doubleValue];
}

- (NSArray*)readArrayForKey:(NSString *)key
           withDefaultValue:(NSArray*)defaultValue
{
    NSArray *array = [self readSecureFromKey:key withDefaultValue:defaultValue classType:[NSArray class]];
    return array;
}

@end
