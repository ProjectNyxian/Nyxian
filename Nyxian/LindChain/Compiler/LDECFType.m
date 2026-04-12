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

#import <LindChain/Compiler/LDECFType.h>

@implementation LDECFType

+ (BOOL)automaticallyNotifiesObserversForKey:(NSString *)key
{
    return NO;
}

- (id)retain
{
    return (__bridge id)CFRetain((__bridge CFTypeRef)self);
}

- (oneway void)release
{
    CFRelease((__bridge CFTypeRef)self);
}

- (unsigned long long)retainCount
{
    return CFGetRetainCount((__bridge CFTypeRef)self);
}

- (BOOL)_tryRetain
{
    if(CFGetRetainCount((__bridge CFTypeRef)self) == 0)
    {
        return NO;
    }
    CFRetain((__bridge CFTypeRef)self);
    return YES;
}

- (BOOL)_isDeallocating
{
    return CFGetRetainCount((__bridge CFTypeRef)self) == 0;
}

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wobjc-missing-super-calls"
- (void)dealloc
{
    /*
     * CF manages the memory of this object
     * and not us, so we cant call
     * [super dealloc], get that in your god damn
     * brain compiler.
     */
}
#pragma clang diagnostic pop

- (NSString *)description
{
    CFStringRef desc = CFCopyDescription((__bridge CFTypeRef)self);
    if(desc == NULL)
    {
        return [super description];
    }
    NSString *result = (__bridge NSString *)desc;
    CFRelease(desc);
    return result;
}

- (unsigned long long)hash
{
    return CFHash((__bridge CFTypeRef)self);
}

- (BOOL)isEqual:(id)other
{
    if(other == nil)
    {
        return NO;
    }
    return (BOOL)CFEqual((__bridge CFTypeRef)self, (__bridge CFTypeRef)other);
}

@end
