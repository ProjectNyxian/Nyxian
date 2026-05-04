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

#ifndef CCFILE_H
#define CCFILE_H

#include <CoreCompiler/CCBase.h>

typedef struct opaque_ccfile *CCFileRef;
typedef struct opaque_ccfile *CCMutableFileRef;

CC_EXPORT CFTypeID CCFileGetTypeID(void);

CC_EXPORT CCFileRef CCFileCreate(CFAllocatorRef allocator, CFURLRef fileURL);
CC_EXPORT CCFileRef CCFileCreateWithFilePath(CFAllocatorRef allocator, CFStringRef filePath);
CC_EXPORT CCFileRef CCFileCreateWithCString(CFAllocatorRef allocator, const char *path, CFStringEncoding encoding);
CC_EXPORT CCMutableFileRef CCFileCreateMutable(CFAllocatorRef allocator, CFURLRef fileURL);
CC_EXPORT CCMutableFileRef CCFileCreateMutableWithUnsavedData(CFAllocatorRef allocator, CFURLRef fileURL, CFDataRef data);
CC_EXPORT CCFileRef CCFileCreateCopy(CFAllocatorRef allocator, CCFileRef file);
CC_EXPORT CCMutableFileRef CCFileCreateMutableCopy(CFAllocatorRef allocator, CCFileRef file);

CC_EXPORT CCFileType CCFileGetType(CCFileRef file);
CC_EXPORT CFURLRef CCFileGetFileURL(CCFileRef file);
CC_EXPORT CFDataRef CCFileGetUnsavedData(CCFileRef file);
CC_EXPORT CFDataRef CCFileCopyUnsavedData(CCFileRef file);
CC_EXPORT void CCFileSetFileURL(CCMutableFileRef mutableFile, CFURLRef fileURL);
CC_EXPORT void CCFileSetUnsavedData(CCMutableFileRef mutableFile, CFDataRef data);

#endif /* CCFILE_H */
