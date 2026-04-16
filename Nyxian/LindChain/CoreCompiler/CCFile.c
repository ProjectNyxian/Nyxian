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

#include <LindChain/CoreCompiler/CCFile.h>

static CFTypeID gCCFileTypeID = _kCFRuntimeNotATypeID;

struct opaque_ccfile {
    CFRuntimeBase _base;
    Boolean isMutable;
    CFURLRef fileURL;
    CFDataRef unsavedData;
};

static CFTypeRef CCFileCopy(CFAllocatorRef allocator,
                            CFTypeRef cf)
{
    return CFRetain(cf);
}

static void CCFileFinalize(CFTypeRef cf)
{
    CCFileRef fileRef = (CCFileRef)cf;
    CFRelease(fileRef->fileURL);
    
    if(fileRef->unsavedData)
    {
        CFRelease(fileRef->unsavedData);
    }
}

static Boolean CCFileEqual(CFTypeRef cf1,
                           CFTypeRef cf2)
{
    CCFileRef fileRef1 = (CCFileRef)cf1;
    CCFileRef fileRef2 = (CCFileRef)cf2;
    return CFEqual(fileRef1->fileURL, fileRef2->fileURL);
}

static CFHashCode CCFileHash(CFTypeRef cf)
{
    CCFileRef fileRef = (CCFileRef)cf;
    return CFHash(fileRef->fileURL);
}

static CFStringRef CCFileCopyFormattingDesc(CFTypeRef cf,
                                            CFDictionaryRef options)
{
    CCFileRef fileRef = (CCFileRef)cf;
    return CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("%@"), fileRef->fileURL);
}

static CFStringRef CCFileCopyDebugDesc(CFTypeRef cf)
{
    CCFileRef fileRef = (CCFileRef)cf;
    return CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("<CCFile %p: fileURL=%@>"), cf, fileRef->fileURL);
}

static const CFRuntimeClass gCCFileClass = {
    0,                              /* version */
    "LDEFile",                      /* class name (later for OBJC type) */
    NULL,                           /* init */
    CCFileCopy,                     /* copy */
    CCFileFinalize,                 /* finalize */
    CCFileEqual,                    /* equal */
    CCFileHash,                     /* hash */
    CCFileCopyFormattingDesc,       /* copyFormattingDesc */
    CCFileCopyDebugDesc,            /* copyDebugDesc */
    NULL,
    NULL,
    0
};

CFTypeID CCFileGetTypeID(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gCCFileTypeID = _CFRuntimeRegisterClass(&gCCFileClass);
    });
    return gCCFileTypeID;
}

CCMutableFileRef CCFileCreateMutable(CFAllocatorRef allocator,
                                     CFURLRef fileURL)
{
    assert(fileURL != nil);
    
    CCMutableFileRef mutableFile = (CCMutableFileRef)_CFRuntimeCreateInstance(allocator, CCFileGetTypeID(), sizeof(struct opaque_ccfile) - sizeof(CFRuntimeBase), NULL);
    if(mutableFile == nil)
    {
        return nil;
    }
    
    mutableFile->isMutable = true;
    mutableFile->fileURL = CFRetain(fileURL);
    mutableFile->unsavedData = nil;
    
    return mutableFile;
}

CCMutableFileRef CCFileCreateMutableWithUnsavedData(CFAllocatorRef allocator,
                                                    CFURLRef fileURL,
                                                    CFDataRef data)
{
    assert(data != nil);
    
    CCMutableFileRef mutableFile = CCFileCreateMutable(allocator, fileURL);
    mutableFile->unsavedData = CFRetain(data);
    
    return mutableFile;
}

static CCFileRef _CCFileCreateCopy(CFAllocatorRef allocator,
                                   CCFileRef file,
                                   bool isMutable)
{
    assert(file != nil);
    
    CCFileRef newFile = (CCFileRef)_CFRuntimeCreateInstance(allocator, CCFileGetTypeID(), sizeof(struct opaque_ccfile) - sizeof(CFRuntimeBase), NULL);
    if(newFile == nil)
    {
        return nil;
    }
    
    newFile->isMutable = isMutable;
    newFile->fileURL = CFRetain(file->fileURL);
    
    if(file->unsavedData == nil)
    {
        newFile->unsavedData = nil;
    }
    else
    {
        newFile->unsavedData = CFRetain(file->unsavedData);
    }
    
    return newFile;
}

CCFileRef CCFileCreateCopy(CFAllocatorRef allocator,
                           CCFileRef file)
{
    return _CCFileCreateCopy(allocator, file, false);
}

CCMutableFileRef CCFileCreateMutableCopy(CFAllocatorRef allocator,
                                         CCFileRef file)
{
    return _CCFileCreateCopy(allocator, file, true);
}

CCFileType CCFileGetType(CCFileRef file)
{
    CFStringRef extension = CFURLCopyPathExtension(file->fileURL);
    if(extension == nil)
    {
        return CCFileTypeUnknown;
    }
    
    /* FIXME: get header types later by project indexing */
    CCFileType type = CCFileTypeUnknown;
    
    if(CFEqual(CFSTR("c"), extension))
    {
        type = CCFileTypeC;
    }
    else if(CFEqual(CFSTR("cpp"), extension) ||
            CFEqual(CFSTR("cc"), extension) ||
            CFEqual(CFSTR("cxx"), extension) ||
            CFEqual(CFSTR("c++"), extension))
    {
        type = CCFileTypeCXX;
    }
    else if(CFEqual(CFSTR("hpp"), extension) ||
            CFEqual(CFSTR("hh"), extension) ||
            CFEqual(CFSTR("h++"), extension) ||
            CFEqual(CFSTR("hxx"), extension))
    {
        type = CCFileTypeCXXHeader;
    }
    else if(CFEqual(CFSTR("h"), extension))
    {
        type = CCFileTypeObjCHeader;
    }
    else if(CFEqual(CFSTR("m"), extension))
    {
        type = CCFileTypeObjC;
    }
    else if(CFEqual(CFSTR("mm"), extension))
    {
        type = CCFileTypeObjCXX;
    }
    else if(CFEqual(CFSTR("swift"), extension))
    {
        type = CCFileTypeSwift;
    }
    
    CFRelease(extension);
    return type;
}

CFURLRef CCFileGetFileURL(CCFileRef file)
{
    return file->fileURL;
}

CFDataRef CCFileGetUnsavedData(CCFileRef file)
{
    if(file->unsavedData == nil)
    {
        return nil;
    }
    return file->unsavedData;
}

CFDataRef CCFileCopyUnsavedData(CCFileRef file)
{
    if(file->unsavedData == nil)
    {
        return nil;
    }
    return CFRetain(file->unsavedData);
}

void CCFileSetFileURL(CCMutableFileRef mutableFile,
                      CFURLRef fileURL)
{
    assert(fileURL != nil && mutableFile->isMutable);
    
    if(mutableFile->fileURL)
    {
        CFRelease(mutableFile->fileURL);
    }
    
    mutableFile->fileURL = CFRetain(fileURL);
}

void CCFileSetUnsavedData(CCMutableFileRef mutableFile,
                          CFDataRef data)
{
    assert(mutableFile->isMutable);
    
    if(mutableFile->unsavedData)
    {
        CFRelease(mutableFile->unsavedData);
    }
    
    if(data == nil)
    {
        /* seems to be now upto date with disk content? */
        mutableFile->unsavedData = nil;
    }
    else
    {
        mutableFile->unsavedData = CFRetain(data);
    }
}
