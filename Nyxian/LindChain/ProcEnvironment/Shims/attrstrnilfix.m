/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2025 - 2026 emexlab

 This file is part of Nyxian.

 Licensed under the emexLabs Public Source License, version 1.1
 (EPSL 1.1).

 Private use and modification are permitted under the license.
 Redistribution of source or binaries, modified or unmodified,
 requires prior written permission from emexLabs.

 External deployment is subject to the source-availability
 requirements and other conditions of the license.

 Provided "AS IS", without warranty, to the extent permitted by law.

 See LICENSE for the full license terms.
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
    @autoreleasepool {
        SwizzleObjCMethod(@selector(initWithString:), NSClassFromString(@"NSConcreteAttributedString"), @selector(hook_initWithString:), [NXCAttrStrFix class], kSwizzleMethodTypeInstance);
    }
}
