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

#include <CoreCompiler/CCFileSourceLocation.h>

static CFTypeID gCCFileSourceLocationTypeID = _kCFRuntimeNotATypeID;

struct opaque_ccfilesourcelocation {
    CFRuntimeBase _base;
    CFURLRef fileURL;
    CCSourceLocation location;
};

static CFTypeRef CCFileSourceLocationCopy(CFAllocatorRef allocator,
                                          CFTypeRef cf)
{
    return CFRetain(cf);
}

static void CCFileSourceLocationFinalize(CFTypeRef cf)
{
    CCFileSourceLocationRef fileSourceLocationRef = (CCFileSourceLocationRef)cf;
    CFRelease(fileSourceLocationRef->fileURL);
}

static Boolean CCFileSourceLocationEqual(CFTypeRef cf1,
                                         CFTypeRef cf2)
{
    CCFileSourceLocationRef fileSourceLocationRef1 = (CCFileSourceLocationRef)cf1;
    CCFileSourceLocationRef fileSourceLocationRef2 = (CCFileSourceLocationRef)cf2;

    if(!CFEqual(fileSourceLocationRef1->fileURL, fileSourceLocationRef2->fileURL))
    {
        return false;
    }

    return CCSourceLocationEqualToLocation(fileSourceLocationRef1->location, fileSourceLocationRef2->location);
}

static CFHashCode CCFileSourceLocationHash(CFTypeRef cf)
{
    CCFileSourceLocationRef fileSourceLocationRef = (CCFileSourceLocationRef)cf;
    return CFHash(fileSourceLocationRef->fileURL);
}

static CFStringRef CCFileSourceLocationCopyFormattingDesc(CFTypeRef cf,
                                                          CFDictionaryRef options)
{
    CCFileSourceLocationRef fileSourceLocationRef = (CCFileSourceLocationRef)cf;
    return CFStringCreateWithFormat(kCFAllocatorSystemDefault, NULL, CFSTR("%@"), fileSourceLocationRef->fileURL);
}

static CFStringRef CCFileSourceLocationCopyDebugDesc(CFTypeRef cf)
{
    CCFileSourceLocationRef fileSourceLocationRef = (CCFileSourceLocationRef)cf;
    return CFStringCreateWithFormat(kCFAllocatorSystemDefault, NULL, CFSTR("<CCFileSourceLocation %p: fileURL=%@ line=%ld column=%ld>"), cf, fileSourceLocationRef->fileURL, (long)fileSourceLocationRef->location.line, (long)fileSourceLocationRef->location.column);
}

static const CFRuntimeClass gCCFileClass = {
    0,                                      /* version */
    "CCKFileSourceLocation",                /* class name (later for OBJC type) */
    NULL,                                   /* init */
    CCFileSourceLocationCopy,               /* copy */
    CCFileSourceLocationFinalize,           /* finalize */
    CCFileSourceLocationEqual,              /* equal */
    CCFileSourceLocationHash,               /* hash */
    CCFileSourceLocationCopyFormattingDesc, /* copyFormattingDesc */
    CCFileSourceLocationCopyDebugDesc,      /* copyDebugDesc */
    NULL,
    NULL,
    0
};

CFTypeID CCFileSourceLocationGetTypeID(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gCCFileSourceLocationTypeID = _CFRuntimeRegisterClass(&gCCFileClass);
    });
    return gCCFileSourceLocationTypeID;
}

CCFileSourceLocationRef CCFileSourceLocationCreate(CFAllocatorRef allocator,
                                                   CFURLRef fileURL,
                                                   CCSourceLocation location)
{
    assert(fileURL != nil);

    CCFileSourceLocationRef fileSourceLocation = (CCFileSourceLocationRef)_CFRuntimeCreateInstance(allocator, CCFileSourceLocationGetTypeID(), sizeof(struct opaque_ccfilesourcelocation) - sizeof(CFRuntimeBase), NULL);
    if(fileSourceLocation == nil)
    {
        return nil;
    }

    fileSourceLocation->fileURL = CFRetain(fileURL);
    fileSourceLocation->location = location;

    return fileSourceLocation;
}

CFURLRef CCFileSourceLocationGetFileURL(CCFileSourceLocationRef fileSourceLocation)
{
    return fileSourceLocation->fileURL;
}

CCSourceLocation CCFileSourceLocationGetLocation(CCFileSourceLocationRef fileSourceLocation)
{
    return fileSourceLocation->location;
}
