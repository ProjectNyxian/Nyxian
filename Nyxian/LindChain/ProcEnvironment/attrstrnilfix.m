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
#import <LindChain/Utils/Swizzle.h>

@interface NXCAttrStrFix : NSObject

@end

@implementation NXCAttrStrFix

- (instancetype)hook_initWithString:(NSString *)str
{
    return [self hook_initWithString:str ? str : @""];
}

@end

__attribute__((constructor))
void attrstrnilfix_init(void)
{
    swizzle_objc_method(@selector(initWithString:), NSClassFromString(@"NSConcreteAttributedString"), @selector(hook_initWithString:), [NXCAttrStrFix class]);
}
