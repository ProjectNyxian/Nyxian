/*
 * MIT License
 *
 * Copyright (c) 2026 mach-port-t
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

#import <CoreCompiler/CCKFile.h>
#import <objc/runtime.h>

@implementation CCKFile

+ (void)load
{
    _CFRuntimeBridgeClasses(CCFileGetTypeID(), "CCKFile");
}

+ (instancetype)fileWithURL:(NSURL*)fileURL
{
    return (__bridge_transfer CCKFile*)CCFileCreate(kCFAllocatorSystemDefault, (__bridge CFURLRef)fileURL);
}

+ (instancetype)fileWithPath:(NSString*)filePath
{
    return (__bridge_transfer CCKFile*)CCFileCreateWithFilePath(kCFAllocatorSystemDefault, (__bridge CFStringRef)filePath);
}

+ (instancetype)fileWithCString:(const char*)path
                       encoding:(NSStringEncoding)encoding
{
    return (__bridge_transfer CCKFile*)CCFileCreateWithCString(kCFAllocatorSystemDefault, path, CFStringConvertNSStringEncodingToEncoding(encoding));
}

- (NSURL*)fileURL
{
    return (__bridge NSURL*)CCFileGetFileURL((__bridge void *)self);
}

- (NSData*)unsavedData
{
    return (__bridge NSData*)CCFileGetUnsavedData((__bridge void *)self);
}

- (CCFileType)type
{
    return CCFileGetType((__bridge void *)self);
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone
{
    return (__bridge_transfer CCKFile*)CCFileCreateCopy(kCFAllocatorSystemDefault, (__bridge CCFileRef)self);
}

- (nonnull id)mutableCopyWithZone:(nullable NSZone *)zone
{
    CCKFile *obj = (__bridge_transfer CCKFile*)CCFileCreateMutableCopy(kCFAllocatorSystemDefault, (__bridge CCFileRef)self);
    object_setClass(obj, [CCKMutableFile class]);
    return (CCKMutableFile *)obj;
}

@end

@implementation CCKMutableFile

@dynamic fileURL;
@dynamic unsavedData;

+ (instancetype)fileWithURL:(NSURL*)fileURL
{
    CCKFile *obj = (__bridge_transfer CCKFile*)CCFileCreateMutable(kCFAllocatorSystemDefault, (__bridge CFURLRef)fileURL);
    object_setClass(obj, [CCKMutableFile class]);
    return (CCKMutableFile *)obj;
}

+ (instancetype)fileWithURL:(NSURL*)fileURL
            withUnsavedData:(NSData*)unsavedData
{
    CCKFile *obj = (__bridge_transfer CCKFile*)CCFileCreateMutableWithUnsavedData(kCFAllocatorSystemDefault, (__bridge CFURLRef)fileURL, (__bridge CFDataRef)unsavedData);
    object_setClass(obj, [CCKMutableFile class]);
    return (CCKMutableFile *)obj;
}

- (void)setFileURL:(NSURL*)fileURL
{
    CCFileSetFileURL((__bridge void *)self, (__bridge CFURLRef)fileURL);
}

- (void)setUnsavedData:(NSData*)unsavedData
{
    CCFileSetUnsavedData((__bridge void *)self, (__bridge CFDataRef)unsavedData);
}

@end
