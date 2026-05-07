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

#ifndef CCDIAGNOSTIC_H
#define CCDIAGNOSTIC_H

#include <CoreCompiler/CCBase.h>
#include <CoreCompiler/CCFileSourceLocation.h>

typedef struct opaque_ccdiag *CCDiagnosticRef;

CC_EXPORT CFTypeID CCDiagnosticGetTypeID(void);

CC_EXPORT CCDiagnosticRef CCDiagnosticCreate(CFAllocatorRef allocator, CCDiagnosticType type, CCDiagnosticLevel level, CFStringRef mainSource, CCFileSourceLocationRef fileSourceLocation, CFStringRef message);

CC_EXPORT CCDiagnosticType CCDiagnosticGetType(CCDiagnosticRef diagnostic);
CC_EXPORT CCDiagnosticLevel CCDiagnosticGetLevel(CCDiagnosticRef diagnostic);
CC_EXPORT CFStringRef CCDiagnosticGetMainSource(CCDiagnosticRef diagnostic);
CC_EXPORT CCFileSourceLocationRef CCDiagnosticGetFileSourceLocation(CCDiagnosticRef diagnostic);
CC_EXPORT CFStringRef CCDiagnosticGetMessage(CCDiagnosticRef diagnostic);

#endif /* CCDIAGNOSTIC_H */
