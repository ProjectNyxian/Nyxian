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

#ifndef CCDEPENDENCYSCANNER_H
#define CCDEPENDENCYSCANNER_H

#include <CoreCompiler/CCBase.h>
#include <CoreCompiler/CCFile.h>

typedef struct opaque_ccdependencyscanner *CCDependencyScannerRef;

CC_EXPORT CFTypeID CCDependencyScannerGetTypeID(void);

CC_EXPORT CCDependencyScannerRef CCDependencyScannerCreate(CFAllocatorRef allocator, CFArrayRef arguments);

CC_EXPORT CFArrayRef CCDependencyScannerCopyDependencyFilesForFile(CCDependencyScannerRef dependencyScanner, CCFileRef file);

#endif /* CCDEPENDENCYSCANNER_H */
