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

#ifndef CCBASE_H
#define CCBASE_H

#include <CoreFoundation/CoreFoundation.h>
#include <CoreCompiler/CFRuntime.h>

#ifdef __cplusplus
#define CC_EXPORT extern "C" __attribute__((visibility("default")))
#define CC_CXX_EXPORT extern __attribute__((visibility("default")))
#else
#define CC_EXPORT extern __attribute__((visibility("default")))
#endif

typedef CF_ENUM(uint8_t, CCDiagnosticType) {
    CCDiagnosticTypeFile = 0,
    CCDiagnosticTypeTargetFile,
    CCDiagnosticTypeInternal,
    CCDiagnosticTypeUnknown,
};

typedef CF_ENUM(uint8_t, CCDiagnosticLevel) {
    CCDiagnosticLevelNote = 0,
    CCDiagnosticLevelRemark,
    CCDiagnosticLevelWarning,
    CCDiagnosticLevelError,
    CCDiagnosticLevelFatal,
    CCDiagnosticLevelUnknown,
};

typedef CF_ENUM(uint8_t, CCJobType) {
    CCJobTypeCompiler = 0,
    CCJobTypeDriver,
    CCJobTypeSwiftCompiler,
    CCJobTypeSwiftDriver,
    CCJobTypeLinker,
    CCJobTypeUnknown
};

typedef CF_ENUM(uint8_t, CCFileType) {
    CCFileTypeC = 0,
    CCFileTypeCHeader,
    CCFileTypeCXX,
    CCFileTypeCXXHeader,
    CCFileTypeObjC,
    CCFileTypeObjCHeader,
    CCFileTypeObjCXX,
    CCFileTypeObjCXXHeader,
    CCFileTypeSwift,
    CCFileTypeObject,
    CCFileTypeUnknown,
};

typedef CF_ENUM(uint8_t, CCDriverType) {
    CCDriverTypeClang = 0,
    CCDriverTypeSwift,
};

CC_EXPORT Boolean CCJobTypeSupportsMultithreading(CCJobType type);

CC_EXPORT Boolean CCFileTypeIsClangFile(CCFileType type);
CC_EXPORT Boolean CCFileTypeIsSwiftFile(CCFileType type);
CC_EXPORT Boolean CCFileTypeIsObjectFile(CCFileType type);

#endif /* CCBASE_H */
