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
#import <Security/Security.h>
#import <LindChain/litehook/litehook.h>

NSMutableDictionary *SecItemPrepare(CFDictionaryRef query)
{
    NSMutableDictionary *queryCopy = ((__bridge NSDictionary *)query).mutableCopy;
    NSString *accessGroup = queryCopy[(__bridge id)kSecAttrAccessGroup];
    NSString *account = queryCopy[(__bridge id)kSecAttrAccount];

    if (!accessGroup)
        accessGroup = [[NSBundle mainBundle] bundleIdentifier];
    if (account)
    {
        [queryCopy removeObjectForKey:(__bridge id)kSecAttrAccessGroup];
        [queryCopy removeObjectForKey:(__bridge id)kSecAttrAccount];
        queryCopy[(__bridge id)kSecAttrAccount] = [NSString stringWithFormat:@"%@@%@", accessGroup, account];
    } else
        [queryCopy removeObjectForKey:(__bridge id)kSecAttrAccessGroup];
    
    return queryCopy;
}

DEFINE_HOOK(SecItemAdd, OSStatus, (CFDictionaryRef query, CFTypeRef *result))
{
    return ORIG_FUNC(SecItemAdd)((__bridge CFDictionaryRef)SecItemPrepare(query), result);
}

DEFINE_HOOK(SecItemCopyMatching, OSStatus, (CFDictionaryRef query, CFTypeRef *result))
{
    return ORIG_FUNC(SecItemCopyMatching)((__bridge CFDictionaryRef)SecItemPrepare(query), result);
}

DEFINE_HOOK(SecItemUpdate, OSStatus, (CFDictionaryRef query, CFDictionaryRef attributesToUpdate))
{
    return ORIG_FUNC(SecItemUpdate)((__bridge CFDictionaryRef)SecItemPrepare(query), (__bridge CFDictionaryRef)SecItemPrepare(attributesToUpdate));
}

DEFINE_HOOK(SecItemDelete, OSStatus, (CFDictionaryRef query))
{
    return ORIG_FUNC(SecItemDelete)((__bridge CFDictionaryRef)SecItemPrepare(query));
}

void SecItemGuestHooksInit(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        DO_HOOK_GLOBAL(SecItemAdd);
        DO_HOOK_GLOBAL(SecItemCopyMatching);
        DO_HOOK_GLOBAL(SecItemUpdate);
        DO_HOOK_GLOBAL(SecItemDelete);
    });
}
