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

#include <LindChain/CoreCompiler/CCUnsavedFile.h>

static CFTypeID gCCUnsavedFileTypeID = _kCFRuntimeNotATypeID;

struct opaque_ccunsavedfile {
    CFRuntimeBase _base;
    CFURLRef fileURL;
    CFDataRef data;
};

static CFTypeRef CCUnsavedFileCopy(CFAllocatorRef allocator,
                                   CFTypeRef cf)
{
    CCUnsavedFileRef unsavedFileRef = (CCUnsavedFileRef)cf;
    return CCUnsavedFileCreate(allocator, unsavedFileRef->fileURL, unsavedFileRef->data);
}

static void CCUnsavedFileFinalize(CFTypeRef cf)
{
    CCUnsavedFileRef unsavedFileRef = (CCUnsavedFileRef)cf;
    CFRelease(unsavedFileRef->fileURL);
    CFRelease(unsavedFileRef->data);
}

static Boolean CCUnsavedFileEqual(CFTypeRef cf1,
                                  CFTypeRef cf2)
{
    CCUnsavedFileRef unsavedFileRef1 = (CCUnsavedFileRef)cf1;
    CCUnsavedFileRef unsavedFileRef2 = (CCUnsavedFileRef)cf2;
    
    if(!CFEqual(unsavedFileRef1->data, unsavedFileRef2->data))
    {
        return false;
    }
    
    return CFEqual(unsavedFileRef1->fileURL, unsavedFileRef2->fileURL);
}

static CFHashCode CCUnsavedFileHash(CFTypeRef cf)
{
    /* TODO: account for data */
    CCUnsavedFileRef unsavedFileRef = (CCUnsavedFileRef)cf;
    return CFHash(unsavedFileRef->fileURL);
}

static CFStringRef CCUnsavedFileCopyFormattingDesc(CFTypeRef cf,
                                                   CFDictionaryRef options)
{
    /* TODO: account for data */
    CCUnsavedFileRef unsavedFileRef = (CCUnsavedFileRef)cf;
    return CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("%@"), unsavedFileRef->fileURL);
}

static CFStringRef CCUnsavedFileCopyDebugDesc(CFTypeRef cf)
{
    CCUnsavedFileRef unsavedFileRef = (CCUnsavedFileRef)cf;
    return CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("<CCUnsavedFile %p: fileURL=%@ data=%@>"), cf, unsavedFileRef->fileURL, unsavedFileRef->data);
}

static const CFRuntimeClass gCCUnsavedFileClass = {
    0,                                  /* version */
    "LDEUnsavedFile",                   /* class name (later for OBJC type) */
    NULL,                               /* init */
    CCUnsavedFileCopy,                  /* copy */
    CCUnsavedFileFinalize,              /* finalize */
    CCUnsavedFileEqual,                 /* equal */
    CCUnsavedFileHash,                  /* hash */
    CCUnsavedFileCopyFormattingDesc,    /* copyFormattingDesc */
    CCUnsavedFileCopyDebugDesc,         /* copyDebugDesc */
    NULL,
    NULL,
    0
};

CFTypeID CCUnsavedFileGetTypeID(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gCCUnsavedFileTypeID = _CFRuntimeRegisterClass(&gCCUnsavedFileClass);
    });
    return gCCUnsavedFileTypeID;
}

CCUnsavedFileRef CCUnsavedFileCreate(CFAllocatorRef allocator,
                                     CFURLRef fileURL,
                                     CFDataRef data)
{
    assert(fileURL != nil && data != nil);
    
    CCUnsavedFileRef unsavedFile = (CCUnsavedFileRef)_CFRuntimeCreateInstance(allocator, CCUnsavedFileGetTypeID(), sizeof(struct opaque_ccunsavedfile) - sizeof(CFRuntimeBase), NULL);
    if(unsavedFile == nil)
    {
        return nil;
    }
    
    unsavedFile->fileURL = CFRetain(fileURL);
    unsavedFile->data = CFRetain(data);
    
    return unsavedFile;
}

CCUnsavedFileRef CCUnsavedFileCreateCopy(CFAllocatorRef allocator,
                                         CCUnsavedFileRef unsavedFile)
{
    return CCUnsavedFileCreate(allocator, unsavedFile->fileURL, unsavedFile->data);
}

CFURLRef CCUnsavedFileGetFileURL(CCUnsavedFileRef unsavedFile)
{
    return unsavedFile->fileURL;
}

CFDataRef CCUnsavedFileGetData(CCUnsavedFileRef unsavedFile)
{
    return unsavedFile->data;
}

void CCUnsavedFileSetFileURL(CCUnsavedFileRef unsavedFile,
                             CFURLRef fileURL)
{
    CFRelease(unsavedFile->fileURL);
    unsavedFile->fileURL = CFRetain(fileURL);
}

void CCUnsavedFileSetData(CCUnsavedFileRef unsavedFile,
                          CFDataRef data)
{
    CFRelease(unsavedFile->data);
    unsavedFile->data = CFRetain(data);
}
