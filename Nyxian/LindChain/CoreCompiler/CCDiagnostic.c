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

static CFTypeRef CCDiagnosticCopy(CFAllocatorRef allocator,
                                  CFTypeRef cf)
{
    return CFRetain(cf);
}

static void CCDiagnosticFinalize(CFTypeRef cf)
{
    CCDiagnosticRef diagnostic = (CCDiagnosticRef)cf;
    if(diagnostic->type != CCDiagTypeInternal)
    {
        CFRelease(diagnostic->fileURL);
    }
    CFRelease(diagnostic->message);
}

static Boolean CCDiagnosticEqual(CFTypeRef cf1,
                                 CFTypeRef cf2)
{
    CCDiagnosticRef diagnostic1 = (CCDiagnosticRef)cf1;
    CCDiagnosticRef diagnostic2 = (CCDiagnosticRef)cf2;
    
    if(diagnostic1->type != diagnostic2->type || diagnostic1->level != diagnostic2->level)
    {
        return false;
    }
    
    if(diagnostic1->type != CCDiagTypeInternal)
    {
        if(!CFEqual(diagnostic1->fileURL, diagnostic2->fileURL))
        {
            return false;
        }
    }
    
    if(!CCSourceLocationEqualToLocation(diagnostic1->location, diagnostic2->location))
    {
        return false;
    }

    if(!CFEqual(diagnostic1->message, diagnostic2->message))
    {
        return false;
    }
    
    return true;
}

static CFHashCode CCDiagnosticHash(CFTypeRef cf)
{
    CCDiagnosticRef diagnostic = (CCDiagnosticRef)cf;
    if(diagnostic->type != CCDiagTypeInternal)
    {
        return CFHash(diagnostic->fileURL) ^ CFHash(diagnostic->message);
    }
    return CFHash(diagnostic->message);
}

static CFStringRef CCDiagnosticCopyFormattingDesc(CFTypeRef cf, CFDictionaryRef options)
{
    CCDiagnosticRef diagnostic = (CCDiagnosticRef)cf;
    if(diagnostic->type != CCDiagTypeInternal)
    {
        return CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("%@:%ld:%ld: %@"), diagnostic->fileURL, diagnostic->location.line, diagnostic->location.column, diagnostic->message);
    }
    return CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("<internal>: %@"), diagnostic->message);
}

static CFStringRef CCDiagnosticCopyDebugDesc(CFTypeRef cf)
{
    CCDiagnosticRef diagnostic = (CCDiagnosticRef)cf;
    return CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("<CCDiagnostic %p: line=%ld col=%ld message=%@>"), cf, diagnostic->location.line, diagnostic->location.column, diagnostic->message);
}

static const CFRuntimeClass gCCDiagnosticClass = {
    0,                              /* version */
    "LDEDiagnostic",                /* class name (later for OBJC type) */
    NULL,                           /* init */
    CCDiagnosticCopy,               /* copy */
    CCDiagnosticFinalize,           /* finalize */
    CCDiagnosticEqual,              /* equal */
    CCDiagnosticHash,               /* hash */
    CCDiagnosticCopyFormattingDesc, /* copyFormattingDesc */
    CCDiagnosticCopyDebugDesc,      /* copyDebugDesc */
};

CFTypeID CCDiagnosticGetTypeID(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gCCDiagnosticTypeID = _CFRuntimeRegisterClass(&gCCDiagnosticClass);
    });
    return gCCDiagnosticTypeID;
}

CCDiagnosticRef CCDiagnosticCreate(CFAllocatorRef allocator,
                                   CCDiagType type,
                                   CCDiagLevel level,
                                   CFURLRef fileURL,
                                   CCSourceLocation location,
                                   CFStringRef message)
{
    assert(message != nil);
    
    struct opaque_ccdiag *diagnostic = (struct opaque_ccdiag*)_CFRuntimeCreateInstance(allocator, CCDiagnosticGetTypeID(), sizeof(struct opaque_ccdiag) - sizeof(CFRuntimeBase), NULL);
    if(diagnostic == nil)
    {
        return nil;
    }
    
    diagnostic->type = type;
    diagnostic->level = level;
    diagnostic->location = location;
    diagnostic->message = CFRetain(message);
    
    if(type != CCDiagTypeInternal)
    {
        diagnostic->fileURL = CFRetain(fileURL);
    }
    
    return (CCDiagnosticRef)diagnostic;
}

CCDiagType CCDiagnosticGetType(CCDiagnosticRef diagnostic)
{
    return diagnostic->type;
}

CCDiagLevel CCDiagnosticGetLevel(CCDiagnosticRef diagnostic)
{
    return diagnostic->level;
}

CFURLRef CCDiagnosticGetFileURL(CCDiagnosticRef diagnostic)
{
    if(diagnostic->type != CCDiagTypeInternal)
    {
        return CFRetain(diagnostic->fileURL);
    }
    else
    {
        return nil;
    }
}

CCSourceLocation CCDiagnosticGetLocation(CCDiagnosticRef diagnostic)
{
    if(diagnostic->type != CCDiagTypeInternal)
    {
        return (diagnostic->location);
    }
    else
    {
        return CCSourceLocationZero;
    }
}

CFStringRef CCDiagnosticGetMessage(CCDiagnosticRef diagnostic)
{
    return CFRetain(diagnostic->message);
}
