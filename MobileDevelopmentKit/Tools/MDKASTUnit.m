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

#import <MobileDevelopmentKit/MDKASTUnit.h>
#import <objc/runtime.h>

@implementation MDKASTUnit

+ (void)load
{
    _CFRuntimeBridgeClasses(CCASTUnitGetTypeID(), "MDKASTUnit");
}

- (MDKFile*)file
{
    return (__bridge MDKFile*)CCASTUnitGetFile((__bridge void *)self);
}

- (NSArray<MDKDiagnostic*>*)diagnostics
{
    return (__bridge_transfer NSArray<MDKDiagnostic*>*)CCASTUnitCopyDiagnostics((__bridge void *)self);
}

- (BOOL)hasErrorOccured
{
    return CCASTUnitErrorOccured((__bridge void *)self);
}

- (MDKFileSourceLocation*)fileSourceLocationForDefinitionAtLocation:(CCSourceLocation)location
{
    return (__bridge_transfer MDKFileSourceLocation*)CCASTUnitCopyDefinitionAtLocation((__bridge void*)self, location);
}

@end

@implementation MDKMutableASTUnit

@dynamic file;

+ (instancetype)unit
{
    MDKASTUnit *obj = (__bridge_transfer MDKASTUnit*)CCASTUnitCreateMutable(kCFAllocatorSystemDefault);
    object_setClass(obj, [MDKMutableASTUnit class]);
    return (MDKMutableASTUnit *)obj;
}

- (void)setFile:(MDKFile*)file
{
    CCASTUnitSetFile((__bridge void *)self, (__bridge CCFileRef)file);
}

- (BOOL)reparse
{
    return CCASTUnitReparse((__bridge void *)self);
}

- (void)setArguments:(NSArray<NSString*>*)arguments
{
    CCASTUnitSetArguments((__bridge void *)self, (__bridge CFArrayRef)arguments);
}

@end
