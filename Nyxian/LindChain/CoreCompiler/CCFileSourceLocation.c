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

#include <LindChain/CoreCompiler/CCFileSourceLocation.h>

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
    return CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("%@"), fileSourceLocationRef->fileURL);
}

static CFStringRef CCFileSourceLocationCopyDebugDesc(CFTypeRef cf)
{
    CCFileSourceLocationRef fileSourceLocationRef = (CCFileSourceLocationRef)cf;
    return CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("<CCFileSourceLocation %p: fileURL=%@ line=%ld column=%ld>"), cf, fileSourceLocationRef->fileURL, (long)fileSourceLocationRef->location.line, (long)fileSourceLocationRef->location.column);
}

static const CFRuntimeClass gCCFileClass = {
    0,                                      /* version */
    "LDEFileSourceLocation",                /* class name (later for OBJC type) */
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
