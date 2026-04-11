/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 cr4zyengineer

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#include <LindChain/CoreCompiler/CCDiagnostic.h>

static CFTypeID gCCDiagnosticTypeID = _kCFRuntimeNotATypeID;

struct opaque_ccdiag {
    CFRuntimeBase _base;
    CCDiagType type;
    CCDiagLevel level;
    CFURLRef fileURL;
    CCSourceLocation location;
    CFStringRef message;
};

static void CCDiagnosticFinalize(CFTypeRef cf)
{
    struct opaque_ccdiag *diagnostic = (struct opaque_ccdiag*)cf;
    CFRelease(diagnostic->fileURL);
    CFRelease(diagnostic->message);
}

static const CFRuntimeClass gCCDiagnosticClass = {
    0,                      /* version */
    "LDEDiagnostic",        /* class name (later for OBJC type) */
    NULL,                   /* init */
    NULL,                   /* copy */
    CCDiagnosticFinalize,   /* finalize */
    NULL,                   /* equal */
    NULL,                   /* hash */
    NULL,                   /* copyFormattingDesc */
    NULL,                   /* copyDebugDesc */
};

CFTypeID CCDiagnosticGetTypeID(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gCCDiagnosticTypeID = _CFRuntimeRegisterClass(&gCCDiagnosticClass);
    });
    return gCCDiagnosticTypeID;
}

CCDiagnosticRef CF_RETURNS_RETAINED CCDiagnosticCreate(CFAllocatorRef allocator,
                                                       CCDiagType type,
                                                       CCDiagLevel level,
                                                       CFURLRef fileURL,
                                                       CCSourceLocation location,
                                                       CFStringRef message)
{
    assert(fileURL != nil && message != nil);
    
    struct opaque_ccdiag *diagnostic = (struct opaque_ccdiag*)_CFRuntimeCreateInstance(allocator, CCDiagnosticGetTypeID(), sizeof(struct opaque_ccdiag) - sizeof(CFRuntimeBase), NULL);
    if(diagnostic == nil)
    {
        return nil;
    }
    
    diagnostic->type = type;
    diagnostic->level = level;
    diagnostic->fileURL = CFRetain(fileURL);
    diagnostic->location = location;
    diagnostic->message = CFRetain(message);
    
    return (CCDiagnosticRef)diagnostic;
}

CCDiagType CCDiagnosticGetType(CCDiagnosticRef diagnostic)
{
    return ((struct opaque_ccdiag*)diagnostic)->type;
}

CCDiagLevel CCDiagnosticGetLevel(CCDiagnosticRef diagnostic)
{
    return ((struct opaque_ccdiag*)diagnostic)->level;
}

CFURLRef CCDiagnosticGetFileURL(CCDiagnosticRef diagnostic)
{
    return CFRetain(((struct opaque_ccdiag*)diagnostic)->fileURL);
}

CCSourceLocation CCDiagnosticGetLocation(CCDiagnosticRef diagnostic)
{
    return ((struct opaque_ccdiag*)diagnostic)->location;
}

CFStringRef CCDiagnosticGetMessage(CCDiagnosticRef diagnostic)
{
    return CFRetain(((struct opaque_ccdiag*)diagnostic)->message);
}
