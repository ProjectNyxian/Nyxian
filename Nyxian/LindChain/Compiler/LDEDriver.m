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

#import <LindChain/Compiler/LDEDriver.h>
#import <Block.h>
#import <objc/runtime.h>

static const char *LDEDriverOutputPathBridge(const char *baseInput, bool *skip, void *ctx)
{
    LDEDriver *driver = (__bridge LDEDriver*)ctx;
    id<LDEDriverDelegate> delegate = driver.delegate;
    
    if(![delegate respondsToSelector:@selector(driver:outputPathForInputFile:skipCompile:)])
    {
        return nil;
    }
    
    NSString *inputPath = [NSString stringWithUTF8String:baseInput];
    NSURL *inputURL = [NSURL fileURLWithPath:inputPath];
    LDEFile *file = [LDEFile fileWithURL:inputURL];
    
    NSString *result = [delegate driver:driver outputPathForInputFile:file skipCompile:skip];
    return result.UTF8String;
}

static const void *LDEDriverDelegateKey = &LDEDriverDelegateKey;

@interface LDEWeakWrapper : NSObject
@property (nonatomic, weak) id<LDEDriverDelegate> delegate;
@end

@implementation LDEWeakWrapper
@end

@implementation LDEDriver

+ (void)load
{
    _CFRuntimeBridgeClasses(CCDriverGetTypeID(), "LDEDriver");
}

+ (instancetype)driverWithArguments:(NSArray<NSString*>*)arguments
{
    return (__bridge_transfer LDEDriver*)CCDriverCreate(kCFAllocatorDefault, (__bridge CFArrayRef)arguments);
}

- (NSArray<LDEJob*>*)generateJobs
{
    return (__bridge_transfer NSArray<LDEJob*>*)CCDriverCopyJobs((__bridge CCDriverRef)self);
}

- (NSURL*)sysrootURL
{
    return (__bridge_transfer NSURL*)CCDriverCopySysrootURL((__bridge CCDriverRef)self);
}

- (LDESDK*)sdk
{
    return (__bridge_transfer LDESDK*)CCDriverCopySDK((__bridge CCDriverRef)self);
}

- (void)setDelegate:(id<LDEDriverDelegate>)delegate
{
    LDEWeakWrapper *wrapper = nil;
    
    if(delegate)
    {
        wrapper = [LDEWeakWrapper new];
        wrapper.delegate = delegate;
    }
    
    objc_setAssociatedObject(self, LDEDriverDelegateKey, wrapper, OBJC_ASSOCIATION_RETAIN);
    
    if(!delegate)
    {
        CCDriverSetOutputPathCallback((__bridge CCDriverRef)self, nil, nil);
        return;
    }
    
    CCDriverSetOutputPathCallback((__bridge CCDriverRef)self, LDEDriverOutputPathBridge, (__bridge void*)self);
}

- (id<LDEDriverDelegate>)delegate
{
    LDEWeakWrapper *wrapper = objc_getAssociatedObject(self, LDEDriverDelegateKey);
    return wrapper.delegate;
}

- (void)dealloc
{
    self.delegate = nil;
}

@end
