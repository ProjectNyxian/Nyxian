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

#import <CoreCompiler/CCKASTUnit.h>
#import <objc/runtime.h>

@implementation CCKASTUnit

+ (void)load
{
    _CFRuntimeBridgeClasses(CCASTUnitGetTypeID(), "CCKASTUnit");
}

- (CCKFile*)file
{
    return (__bridge CCKFile*)CCASTUnitGetFile((__bridge void *)self);
}

- (NSArray<CCKDiagnostic*>*)diagnostics
{
    return (__bridge_transfer NSArray<CCKDiagnostic*>*)CCASTUnitCopyDiagnostics((__bridge void *)self);
}

- (BOOL)hasErrorOccured
{
    return CCASTUnitErrorOccured((__bridge void *)self);
}

- (CCKFileSourceLocation*)fileSourceLocationForDefinitionAtLocation:(CCSourceLocation)location
{
    return (__bridge_transfer CCKFileSourceLocation*)CCASTUnitCopyDefinitionAtLocation((__bridge void*)self, location);
}

@end

@implementation CCKMutableASTUnit

@dynamic file;

+ (instancetype)unit
{
    CCKASTUnit *obj = (__bridge_transfer CCKASTUnit*)CCASTUnitCreateMutable(kCFAllocatorSystemDefault);
    object_setClass(obj, [CCKMutableASTUnit class]);
    return (CCKMutableASTUnit *)obj;
}

- (void)setFile:(CCKFile*)file
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
