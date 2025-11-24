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

#import <LindChain/ProcEnvironment/Server/Trust.h>

@implementation TrustCache

- (instancetype)init
{
    self = [super init];
    
    NSDictionary *udiCache = [[NSUserDefaults standardUserDefaults] objectForKey:@"trustcache"];
    
    _cache = udiCache ? [udiCache mutableCopy] : [[NSMutableDictionary alloc] init];

    return self;
}

+ (instancetype)shared
{
    static TrustCache *trustCacheSingleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        trustCacheSingleton = [[TrustCache alloc] init];
    });
    return trustCacheSingleton;
}

- (PEEntitlement)getEntitlementsForHash:(NSString*)hash
{
    if([hash isEqualToString:@"com.cr4zy.nyxian.daemon.trustcache_daemon"])
    {
        return PEEntitlementSystemApplication;
    }
    else
    {
        NSNumber *entitlementObject = [_cache objectForKey:hash];
        if(entitlementObject)
        {
            return [entitlementObject unsignedLongLongValue];
        }
    }
    return PEEntitlementSandboxedApplication;
}

- (void)setEntitlementsForHash:(NSString *)hash
             usingEntitlements:(PEEntitlement)entitlements
{
    [_cache setValue:[NSNumber numberWithUnsignedLongLong:entitlements] forKey:hash];
    [[NSUserDefaults standardUserDefaults] setObject:_cache forKey:@"trustcache"];
}

@end
