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

- (instancetype)initWithPlistPath:(NSString*)plistPath
{
    self = [super init];
    _plistPath = plistPath;
    _savedHash = [self currentHash];
    [self reloadData];
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
    BOOL needsReload = ![hash isEqualToString:_savedHash];
    if(needsReload)
    {
        _dictionary = [[NSMutableDictionary alloc] initWithContentsOfFile:_plistPath];
        _savedHash = hash;
    }
    return needsReload;
}

- (void)reloadData
{
    _dictionary = [[NSMutableDictionary alloc] initWithContentsOfFile:_plistPath];
    _savedHash = [self currentHash];
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
    return [_dictionary objectForKey:key];
}

- (id)readSecureFromKey:(NSString*)key
       withDefaultValue:(id)value
              classType:Class
{
    id valueOfKey = [_dictionary objectForKey:key];
    if(!valueOfKey && ![valueOfKey isKindOfClass:Class])
        valueOfKey = value;
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
