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

static const char *LDEDriverOutputPathBridge(const char *baseInput, void *ctx)
{
    NSString *(^b)(NSString *) = (__bridge NSString*(^)(NSString *))ctx;
    NSString *result = b([NSString stringWithUTF8String:baseInput]);
    return result.UTF8String;
}

@implementation LDEDriver

+ (void)load
{
    _CFRuntimeBridgeClasses(CCDriverGetTypeID(), "LDEDriver");
}

+ (instancetype)driverWithArguments:(NSArray<NSString*>*)arguments
{
    return (__bridge_transfer LDEDriver*)CCDriverCreate(kCFAllocatorDefault, (__bridge CFArrayRef)arguments);
}

- (NSArray<LDEJob*>*)jobs
{
    return (__bridge_transfer NSArray<LDEJob*>*)CCDriverCopyJobs((__bridge CCDriverRef)self);
}

- (void)setOutputPathCallback:(NSString *(^)(NSString *))outputPathCallback
{
    CCDriverRef ref = (__bridge CCDriverRef)self;
    
    void *ctx = CCDriverGetOutputPathCallbackContext(ref);
    if(ctx)
    {
        Block_release(ctx);
    }
    
    if(!outputPathCallback)
    {
        CCDriverSetOutputPathCallback(ref, nil, nil);
        return;
    }
    
    void *heapBlock = Block_copy((__bridge void *)outputPathCallback);
    
    CCDriverSetOutputPathCallback(ref, LDEDriverOutputPathBridge, heapBlock);
}

- (NSString *(^)(NSString *))outputPathCallback
{
    void *ctx = CCDriverGetOutputPathCallbackContext((CCDriverRef)(__bridge CFTypeRef)self);
    if(!ctx)
    {
        return nil;
    }
    return (__bridge NSString*(^)(NSString *))ctx;
}

- (void)dealloc
{
    self.outputPathCallback = nil;
}

@end
