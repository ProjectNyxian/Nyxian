/*
 * MIT License
 *
 * Copyright (c) 2024 light-tech
 * Copyright (c) 2026 cr4zyengineer
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#import <CoreCompiler/CCKDriver.h>
#import <CoreCompiler/CCDriver.h>
#import <Block.h>
#import <objc/runtime.h>

static CFStringRef CCKDriverOutputPathBridge(const char *baseInput,
                                             bool *skip,
                                             void *ctx)
{
    CCKDriver *driver = (__bridge CCKDriver*)ctx;
    id<CCKDriverDelegate> delegate = driver.delegate;

    CCKFile *file = [CCKFile fileWithCString:baseInput encoding:NSUTF8StringEncoding];
    if(file == nil)
    {
        /* file creation failure */
        return nil;
    }

    if([delegate respondsToSelector:@selector(driver:skipCompileForInputFile:)])
    {
        *skip = [delegate driver:driver skipCompileForInputFile:file];
    }

    if(![delegate respondsToSelector:@selector(driver:outputPathForInputFile:)])
    {
        return nil;
    }

    NSString *result = [delegate driver:driver outputPathForInputFile:file];
    return (__bridge_retained CFStringRef)result;
}

static const void *CCKDriverDelegateKey = &CCKDriverDelegateKey;

@interface CCKWeakWrapper : NSObject
@property (nonatomic, weak) id<CCKDriverDelegate> delegate;
@end

@implementation CCKWeakWrapper
@end

@implementation CCKDriver

+ (void)load
{
    _CFRuntimeBridgeClasses(CCDriverGetTypeID(), "CCKDriver");
}

+ (instancetype)driverWithArguments:(NSArray<NSString*>*)arguments
                           withType:(CCDriverType)type
{
    return (__bridge_transfer CCKDriver*)CCDriverCreate(kCFAllocatorSystemDefault, (__bridge CFArrayRef)arguments, type);
}

- (NSArray<CCKJob*>*)generateJobs
{
    return (__bridge_transfer NSArray<CCKJob*>*)CCDriverCreateJobs((__bridge CCDriverRef)self);
}

- (NSURL*)sysrootURL
{
    return (__bridge_transfer NSURL*)CCDriverCopySysrootURL((__bridge CCDriverRef)self);
}

- (CCKSDK*)sdk
{
    return (__bridge_transfer CCKSDK*)CCDriverCopySDK((__bridge CCDriverRef)self);
}

- (void)setDelegate:(id<CCKDriverDelegate>)delegate
{
    CCKWeakWrapper *wrapper = nil;
    
    if(delegate)
    {
        wrapper = [CCKWeakWrapper new];
        wrapper.delegate = delegate;
    }
    
    objc_setAssociatedObject(self, CCKDriverDelegateKey, wrapper, OBJC_ASSOCIATION_RETAIN);
    
    if(!delegate)
    {
        CCDriverSetOutputPathCallback((__bridge CCDriverRef)self, nil, nil);
        return;
    }
    
    CCDriverSetOutputPathCallback((__bridge CCDriverRef)self, CCKDriverOutputPathBridge, (__bridge void*)self);
}

- (id<CCKDriverDelegate>)delegate
{
    CCKWeakWrapper *wrapper = objc_getAssociatedObject(self, CCKDriverDelegateKey);
    return wrapper.delegate;
}

- (void)dealloc
{
    self.delegate = nil;
}

@end
