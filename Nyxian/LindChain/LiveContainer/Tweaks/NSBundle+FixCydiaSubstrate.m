/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2023 - 2026 LiveContainer
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
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#import <Foundation/Foundation.h>
#import <LindChain/LiveContainer/Tweaks/Tweaks.h>
#import <objc/runtime.h>

@implementation NSString(LiveContainer)

- (NSString *)lc_realpath {
    char result[PATH_MAX];
    realpath(self.fileSystemRepresentation, result);
    return [NSString stringWithUTF8String:result];
}

@end

@implementation NSBundle(LiveContainer)

- (instancetype)initWithPathForMainBundle:(NSString *)path {
    id cfBundle = CFBridgingRelease(CFBundleCreate(NULL, (__bridge CFURLRef)[NSURL fileURLWithPath:path.lc_realpath]));
    if(!cfBundle) return nil;
    self = [self initWithPath:path];
    object_setIvar(self, class_getInstanceVariable(self.class, "_cfBundle"), cfBundle);
    return self;
}

@end
