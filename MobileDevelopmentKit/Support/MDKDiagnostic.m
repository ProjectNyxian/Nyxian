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

#import <MobileDevelopmentKit/MDKDiagnostic.h>

@implementation MDKDiagnostic

+ (void)load
{
    _CFRuntimeBridgeClasses(CCDiagnosticGetTypeID(), "MDKDiagnostic");
}

+ (instancetype)diagnosticWithType:(CCDiagnosticType)type
                             level:(CCDiagnosticLevel)level
                        mainSource:(NSString*)mainSource
                fileSourceLocation:(MDKFileSourceLocation *)fileSourceLocation
                           message:(NSString*)message
{
    /* FIXME: will crash without message */
    return (__bridge_transfer MDKDiagnostic*)CCDiagnosticCreate(kCFAllocatorSystemDefault, type, level, (__bridge CFStringRef)mainSource, (__bridge CCFileSourceLocationRef)fileSourceLocation, (__bridge CFStringRef)message);
}

- (CCDiagnosticType)type
{
    return CCDiagnosticGetType((__bridge void *)self);
}

- (CCDiagnosticLevel)level
{
    return CCDiagnosticGetLevel((__bridge void *)self);
}

- (NSString*)mainSource
{
    return (__bridge NSString*)CCDiagnosticGetMainSource((__bridge void *)self);
}

- (MDKFileSourceLocation*)fileSourceLocation
{
    return (__bridge MDKFileSourceLocation*)CCDiagnosticGetFileSourceLocation((__bridge void *)self);
}

- (NSString*)message
{
    return (__bridge NSString*)CCDiagnosticGetMessage((__bridge void *)self);
}

@end
