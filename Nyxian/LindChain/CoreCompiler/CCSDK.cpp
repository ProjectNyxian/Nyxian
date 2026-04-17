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

#include <LindChain/CoreCompiler/CCSDK.h>
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
    "LDESDK",                       /* class name (later for OBJC type) */
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
