/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 khanhduytran0
 Copyright (C) 2026 cr4zyengineer

 This file is part of LiveContainer.

 LiveContainer is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 LiveContainer is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with LiveContainer. If not, see <https://www.gnu.org/licenses/>.
*/

#import <LindChain/Private/FoundationPrivate.h>
#import <Foundation/Foundation.h>
#import <LindChain/LiveContainer/Tweaks/Tweaks.h>
#import <LindChain/Utils/Swizzle.h>

// NSFileManager simulate app group
@implementation NSFileManager (LiveContainer)

- (NSURL*)hook_containerURLForSecurityApplicationGroupIdentifier:(NSString *)groupIdentifier
{
    NSURL *result;
    result = [NSURL fileURLWithPath:[NSString stringWithFormat:@"%s/Documents/AppGroup/%@", getenv("LC_HOME_PATH"), groupIdentifier]];
    [NSFileManager.defaultManager createDirectoryAtURL:result withIntermediateDirectories:YES attributes:nil error:nil];
    return result;
}

@end

void NSFMGuestHooksInit(void) {
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        swizzle_objc_method(@selector(containerURLForSecurityApplicationGroupIdentifier:), [NSFileManager class], @selector(hook_containerURLForSecurityApplicationGroupIdentifier:), nil);
    });
}
