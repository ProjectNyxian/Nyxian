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

#include <CoreCompiler/CCFile.h>

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
    return CFStringCreateWithFormat(kCFAllocatorSystemDefault, NULL, CFSTR("%@"), fileRef->fileURL);
}

static CFStringRef CCFileCopyDebugDesc(CFTypeRef cf)
{
    CCFileRef fileRef = (CCFileRef)cf;
    return CFStringCreateWithFormat(kCFAllocatorSystemDefault, NULL, CFSTR("<CCFile %p: fileURL=%@>"), cf, fileRef->fileURL);
}

static const CFRuntimeClass gCCFileClass = {
    0,                              /* version */
    "CCFile",                       /* class name */
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

CCFileRef CCFileCreate(CFAllocatorRef allocator,
                       CFURLRef fileURL)
{
    assert(fileURL != nil);

    CCFileRef file = (CCFileRef)_CFRuntimeCreateInstance(allocator, CCFileGetTypeID(), sizeof(struct opaque_ccfile) - sizeof(CFRuntimeBase), NULL);
    if(file == nil)
    {
        return nil;
    }

    file->isMutable = false;
    file->fileURL = CFRetain(fileURL);
    file->unsavedData = nil;

    return file;
}

CCFileRef CCFileCreateWithFilePath(CFAllocatorRef allocator,
                                   CFStringRef filePath)
{
    CFURLRef fileURL = CFURLCreateWithFileSystemPath(allocator, filePath, kCFURLPOSIXPathStyle, false); /* its never a directory if it's a CCFileRef */
    if(fileURL == nil)
    {
        return nil;
    }

    CCFileRef file = CCFileCreate(allocator, fileURL);
    CFRelease(fileURL);
    return file;
}

CCFileRef CCFileCreateWithCString(CFAllocatorRef allocator,
                                  const char *path,
                                  CFStringEncoding encoding)
{
    CFStringRef filePath = CFStringCreateWithCString(allocator, path, encoding);
    if(filePath == nil)
    {
        return nil;
    }

    CCFileRef file = CCFileCreateWithFilePath(allocator, filePath);
    CFRelease(filePath);
    return file;
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
    else if(CFEqual(CFSTR("o"), extension))
    {
        type = CCFileTypeObject;
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
