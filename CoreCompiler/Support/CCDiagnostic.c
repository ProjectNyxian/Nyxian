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

#include <CoreCompiler/CCDiagnostic.h>

static CFTypeID gCCDiagnosticTypeID = _kCFRuntimeNotATypeID;

struct opaque_ccdiag {
    CFRuntimeBase _base;
    CCDiagnosticType type;
    CCDiagnosticLevel level;
    CFStringRef mainSource;
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
    "CCKDiagnostic",                /* class name (later for OBJC type) */
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
                                             CFStringRef mainSource,
                                             CCFileSourceLocationRef fileSourceLocation,
                                             CFStringRef message)
{
    assert(message != nil && mainSource != nil);
    
    CCDiagnosticRef diagnostic = (CCDiagnosticRef)_CFRuntimeCreateInstance(allocator, CCDiagnosticGetTypeID(), sizeof(struct opaque_ccdiag) - sizeof(CFRuntimeBase), NULL);
    if(diagnostic == nil)
    {
        return nil;
    }
    
    diagnostic->type = type;
    diagnostic->level = level;
    diagnostic->mainSource = CFRetain(mainSource);
    
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

CC_EXPORT CFStringRef CCDiagnosticGetMainSource(CCDiagnosticRef diagnostic)
{
    return diagnostic->mainSource;
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
