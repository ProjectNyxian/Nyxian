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
    CCDiagnosticType type;
    CCDiagnosticLevel level;
    CCFileSourceLocationRef fileSourceLocation;
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
    if(diagnostic->fileSourceLocation != nil)
    {
        CFRelease(diagnostic->fileSourceLocation);
    }
    if(diagnostic->message != nil)
    {
        CFRelease(diagnostic->message);
    }
}

static Boolean CCDiagnosticEqual(CFTypeRef cf1,
                                 CFTypeRef cf2)
{
    CCDiagnosticRef diagnostic1 = (CCDiagnosticRef)cf1;
    CCDiagnosticRef diagnostic2 = (CCDiagnosticRef)cf2;
    
    if(diagnostic1->fileSourceLocation != nil)
    {
        if(diagnostic2->fileSourceLocation == nil)
        {
            return false;
        }
        
        if(!CFEqual(diagnostic1->fileSourceLocation, diagnostic2->fileSourceLocation))
        {
            return false;
        }
    }
    else if(diagnostic2->fileSourceLocation != nil)
    {
        return false;
    }
    
    if(diagnostic1->type != diagnostic2->type || diagnostic1->level != diagnostic2->level)
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
    if(diagnostic->fileSourceLocation != nil)
    {
        return CFHash(diagnostic->fileSourceLocation) ^ CFHash(diagnostic->message);
    }
    return CFHash(diagnostic->message);
}

static CFStringRef CCDiagnosticCopyFormattingDesc(CFTypeRef cf, CFDictionaryRef options)
{
    CCDiagnosticRef diagnostic = (CCDiagnosticRef)cf;
    if(diagnostic->type != CCDiagnosticTypeInternal)
    {
        return CFStringCreateWithFormat(kCFAllocatorSystemDefault, NULL, CFSTR("%@: \"%@\""), diagnostic->fileSourceLocation, diagnostic->message);
    }
    return CFStringCreateWithFormat(kCFAllocatorSystemDefault, NULL, CFSTR("<internal>: \"%@\""), diagnostic->message);
}

static CFStringRef CCDiagnosticCopyDebugDesc(CFTypeRef cf)
{
    CCDiagnosticRef diagnostic = (CCDiagnosticRef)cf;
    return CFStringCreateWithFormat(kCFAllocatorSystemDefault, NULL, CFSTR("<CCDiagnostic %p: location=%@ message=\"%@\">"), cf, diagnostic->fileSourceLocation, diagnostic->message);
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
    NULL,
    NULL,
    0
};

CFTypeID CCDiagnosticGetTypeID(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gCCDiagnosticTypeID = _CFRuntimeRegisterClass(&gCCDiagnosticClass);
    });
    return gCCDiagnosticTypeID;
}

CC_EXPORT CCDiagnosticRef CCDiagnosticCreate(CFAllocatorRef allocator,
                                             CCDiagnosticType type,
                                             CCDiagnosticLevel level,
                                             CCFileSourceLocationRef fileSourceLocation,
                                             CFStringRef message)
{
    CCDiagnosticRef diagnostic = (CCDiagnosticRef)_CFRuntimeCreateInstance(allocator, CCDiagnosticGetTypeID(), sizeof(struct opaque_ccdiag) - sizeof(CFRuntimeBase), NULL);
    if(diagnostic == nil)
    {
        return nil;
    }
    
    diagnostic->type = type;
    diagnostic->level = level;
    
    if(fileSourceLocation != nil)
    {
        diagnostic->fileSourceLocation = (CCFileSourceLocationRef)CFRetain(fileSourceLocation);
    }
    diagnostic->message = CFRetain(message);
    
    return diagnostic;
}

CCDiagnosticType CCDiagnosticGetType(CCDiagnosticRef diagnostic)
{
    return diagnostic->type;
}

CCDiagnosticLevel CCDiagnosticGetLevel(CCDiagnosticRef diagnostic)
{
    return diagnostic->level;
}

CCFileSourceLocationRef CCDiagnosticGetFileSourceLocation(CCDiagnosticRef diagnostic)
{
    if(diagnostic->fileSourceLocation != nil)
    {
        return diagnostic->fileSourceLocation;
    }
    else
    {
        return nil;
    }
}

CFStringRef CCDiagnosticGetMessage(CCDiagnosticRef diagnostic)
{
    return diagnostic->message;
}
