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

#ifndef CCASTUNIT_T
#define CCASTUNIT_T

#include <CoreCompiler/CCBase.h>
#include <CoreCompiler/CCDiagnostic.h>
#include <CoreCompiler/CCFile.h>
#include <CoreCompiler/CCFileSourceLocation.h>

typedef struct opaque_ccastunit *CCMutableASTUnitRef;
typedef struct opaque_ccastunit *CCASTUnitRef;

CC_EXPORT CFTypeID CCASTUnitGetTypeID(void);

CC_EXPORT CCMutableASTUnitRef CCASTUnitCreateMutable(CFAllocatorRef allocator);

CC_EXPORT Boolean CCASTUnitReparse(CCMutableASTUnitRef mutableUnit);

CC_EXPORT void CCASTUnitSetArguments(CCMutableASTUnitRef mutableUnit, CFArrayRef arguments);

CC_EXPORT void CCASTUnitSetFile(CCMutableASTUnitRef mutableUnit, CCFileRef file);
CC_EXPORT CCFileRef CCASTUnitGetFile(CCASTUnitRef unit);
CC_EXPORT CCFileRef CCASTUnitCopyFile(CCASTUnitRef unit);

CC_EXPORT Boolean CCASTUnitErrorOccured(CCASTUnitRef unit);

CC_EXPORT CCFileSourceLocationRef CCASTUnitCopyDefinitionAtLocation(CCASTUnitRef unit, CCSourceLocation location);

CC_EXPORT CFArrayRef CCASTUnitCopyDiagnostics(CCASTUnitRef unit);

#endif /* CCASTUNIT_T */
