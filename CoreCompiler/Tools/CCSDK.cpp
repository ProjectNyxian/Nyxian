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

#include <CoreCompiler/CCSDK.h>
#include <clang/Basic/DarwinSDKInfo.h>
#include <llvm/Support/VirtualFileSystem.h>

using namespace clang;
using namespace llvm;

static CFTypeID gCCSDKTypeID = _kCFRuntimeNotATypeID;

struct opaque_ccsdk {
    CFRuntimeBase _base;
    std::unique_ptr<clang::DarwinSDKInfo>(sdkInfo);
};

static CFTypeRef CCSDKCopy(CFAllocatorRef allocator,
                           CFTypeRef cf)
{
    return CFRetain(cf);
}

static void CCSDKFinalize(CFTypeRef cf)
{
    CCSDKRef sdkRef = (CCSDKRef)cf;
    sdkRef->sdkInfo.reset();
}

static const CFRuntimeClass gCCSDKClass = {
    0,                              /* version */
    "CCSDK",                        /* class name */
    NULL,                           /* init */
    CCSDKCopy,                      /* copy */
    CCSDKFinalize,                  /* finalize */
    NULL,                           /* equal */
    NULL,                           /* hash */
    NULL,                           /* copyFormattingDesc */
    NULL,                           /* copyDebugDesc */
    NULL,
    NULL,
    0
};

CFTypeID CCSDKGetTypeID(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gCCSDKTypeID = _CFRuntimeRegisterClass(&gCCSDKClass);
    });
    return gCCSDKTypeID;
}

CCSDKRef CCSDKCreateWithFileURL(CFAllocatorRef allocator,
                                CFURLRef fileURL)
{
    assert(fileURL != nullptr);
    
    CCSDKRef sdkRef = (CCSDKRef)_CFRuntimeCreateInstance(allocator, CCSDKGetTypeID(), sizeof(struct opaque_ccsdk) - sizeof(CFRuntimeBase), NULL);
    if(sdkRef == nullptr)
    {
        return nullptr;
    }
    
    CFStringRef pathStr = CFURLGetString(fileURL);
    if(pathStr == nullptr)
    {
        CFRelease(sdkRef);
        return nullptr;
    }
    
    const char *cPathStr = CFStringGetCStringPtr(pathStr, kCFStringEncodingUTF8);
    if(cPathStr == nullptr)
    {
        CFRelease(sdkRef);
        return nullptr;
    }
    
    auto result = clang::parseDarwinSDKInfo(
        *llvm::vfs::getRealFileSystem(),
        std::string(cPathStr)
    );
    
    if(!result || !*result)
    {
        CFRelease(sdkRef);
        return nullptr;
    }
    
    sdkRef->sdkInfo = std::make_unique<clang::DarwinSDKInfo>(std::move(**result));
    
    return sdkRef;
}

CFStringRef CCSDKCopyVersion(CCSDKRef sdk)
{
    VersionTuple versionTuple = sdk->sdkInfo->getVersion();
    std::string versionStr = versionTuple.getAsString();
    if(versionStr.empty())
    {
        return nullptr;
    }
    
    const char *versionCStr = versionStr.c_str();
    if(versionCStr == nullptr)
    {
        return nullptr;
    }
    
    return CFStringCreateWithCString(CFGetAllocator(sdk), versionCStr, kCFStringEncodingUTF8);
}
