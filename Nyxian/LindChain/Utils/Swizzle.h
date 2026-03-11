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

#ifndef LINDCHAIN_UTILS_SWIZZLE_H
#define LINDCHAIN_UTILS_SWIZZLE_H

#import <Foundation/Foundation.h>
#import <objc/runtime.h>

enum SWIZZLE_RETURN
{
    SWIZZLE_RETURN_SUCCESS              = 0b00000000,
    SWIZZLE_RETURN_ARGUMENTS            = 0b00000001,
    SWIZZLE_RETURN_METHOD_TYPE          = 0b00000010
};

enum SWIZZLE_METHOD_TYPE
{
    SWIZZLE_METHOD_TYPE_CLASS    = 0b00000000,
    SWIZZLE_METHOD_TYPE_INSTANCE = 0b00000001
};

unsigned char swizzle_objc_method(SEL originalAction, Class originalClass, SEL replacementAction, Class replacementClass);

#endif /* LINDCHAIN_UTILS_SWIZZLE_H */
