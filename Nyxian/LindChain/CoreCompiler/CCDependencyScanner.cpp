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

#include <LindChain/CoreCompiler/CCDependencyScanner.h>
#include <clang/Tooling/DependencyScanning/DependencyScanningTool.h>
#include <clang/Tooling/DependencyScanning/DependencyScanningService.h>
#include <clang/Tooling/CompilationDatabase.h>
#include <llvm/Support/VirtualFileSystem.h>

using namespace clang;
using namespace clang::tooling::dependencies;

static CFTypeID gCCDependencyScannerTypeID = _kCFRuntimeNotATypeID;

struct opaque_ccdependencyscanner {
    CFRuntimeBase _base;
    DependencyScanningService service;
    std::vector<std::string> BaseArgs;
    std::string sysroot;
    std::string resourceDir;
};

static void CCDependencyScannerFinalize(CFTypeRef cf)
{
    CCDependencyScannerRef dependencyScanner = (CCDependencyScannerRef)cf;
    dependencyScanner->service.~DependencyScanningService();
    dependencyScanner->BaseArgs.~vector();
    dependencyScanner->sysroot.~basic_string();
    dependencyScanner->resourceDir.~basic_string();
}

static void CCDependencyScannerInit(CFTypeRef cf)
{
    CCDependencyScannerRef dependencyScanner = (CCDependencyScannerRef)cf;
    new (&dependencyScanner->service) DependencyScanningService(ScanningMode::DependencyDirectivesScan, ScanningOutputFormat::Full, ScanningOptimizations::Default, false);
    new (&dependencyScanner->BaseArgs) std::vector<std::string>();
    new (&dependencyScanner->sysroot) std::string();
    new (&dependencyScanner->resourceDir) std::string();
}

static const CFRuntimeClass gCCDependencyScannerClass = {
    0,                              /* version */
    "LDEDependencyScanner",         /* class name (later for OBJC type) */
    CCDependencyScannerInit,        /* init */
    NULL,                           /* copy */
    CCDependencyScannerFinalize,    /* finalize */
    NULL,                           /* equal */
    NULL,                           /* hash */
    NULL,                           /* copyFormattingDesc */
    NULL,                           /* copyDebugDesc */
    NULL,
    NULL,
    0
};

CFTypeID CCDependencyScannerGetTypeID(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gCCDependencyScannerTypeID = _CFRuntimeRegisterClass(&gCCDependencyScannerClass);
    });
    return gCCDependencyScannerTypeID;
}

CCDependencyScannerRef CCDependencyScannerCreate(CFAllocatorRef allocator,
                                                 CFArrayRef arguments)
{
    assert(arguments != nullptr);
    
    CCDependencyScannerRef dependencyScanner = (CCDependencyScannerRef)_CFRuntimeCreateInstance(allocator, CCDependencyScannerGetTypeID(), sizeof(struct opaque_ccdependencyscanner) - sizeof(CFRuntimeBase), NULL);
    if(dependencyScanner == nullptr)
    {
        return nullptr;
    }
    
    dependencyScanner->BaseArgs.push_back("clang");
    CFIndex count = CFArrayGetCount(arguments);
    for(CFIndex i = 0; i < count; i++)
    {
        CFStringRef arg = (CFStringRef)CFArrayGetValueAtIndex(arguments, i);
        const char *ptr = CFStringGetCStringPtr(arg, kCFStringEncodingUTF8);
        if(ptr)
        {
            dependencyScanner->BaseArgs.push_back(ptr);
        }
        else
        {
            char buf[1024];
            CFStringGetCString(arg, buf, sizeof(buf), kCFStringEncodingUTF8);
            dependencyScanner->BaseArgs.push_back(buf);
        }
    }
    
    for(size_t i = 0; i < dependencyScanner->BaseArgs.size(); i++)
    {
        if(dependencyScanner->BaseArgs[i] == "-isysroot" && i + 1 < dependencyScanner->BaseArgs.size())
        {
            dependencyScanner->sysroot = dependencyScanner->BaseArgs[i + 1];
            i++;
        }
        else if(llvm::StringRef(dependencyScanner->BaseArgs[i]).starts_with("-isysroot") && dependencyScanner->BaseArgs[i].size() > 9)
        {
            dependencyScanner->sysroot = dependencyScanner->BaseArgs[i].substr(9);
        }
        else if(dependencyScanner->BaseArgs[i] == "-resource-dir" && i + 1 < dependencyScanner->BaseArgs.size())
        {
            dependencyScanner->resourceDir = dependencyScanner->BaseArgs[i + 1];
            i++;
        }
        else if(llvm::StringRef(dependencyScanner->BaseArgs[i]).starts_with("-resource-dir="))
        {
            dependencyScanner->resourceDir = dependencyScanner->BaseArgs[i].substr(strlen("-resource-dir="));
        }
    }
    
    return dependencyScanner;
}

CFArrayRef CCDependencyScannerCopyDependencyFilesForFile(CCDependencyScannerRef dependencyScanner,
                                                         CCFileRef file)
{
    assert(file != nullptr);
    
    CFURLRef fileURL = CCFileGetFileURL(file);
    if(fileURL == nullptr)  /* MARK: might be guranteed */
    {
        return nullptr;
    }
    
    CFStringRef filePath = CFURLCopyFileSystemPath(fileURL, kCFURLPOSIXPathStyle);
    if(filePath == nullptr)
    {
        return nullptr;
    }
    
    const char *filePathCStr = CFStringGetCStringPtr(filePath, kCFStringEncodingUTF8);
    if(filePathCStr == nullptr)
    {
        CFRelease(filePath);
        return nullptr;
    }
    
    DependencyScanningTool tool(dependencyScanner->service);
    
    std::vector<std::string> Args = dependencyScanner->BaseArgs;
    Args.push_back(filePathCStr);
    CFRelease(filePath);
    
    llvm::Expected<std::string> depsOrErr = tool.getDependencyFile(Args, "/");
    if(!depsOrErr)
    {
        /* failed */
        return nullptr;
    }
    
    std::string depStr = *depsOrErr;
    size_t colonPos = depStr.find(':');
    if(colonPos == std::string::npos)
    {
        /* no scan output */
        return nullptr;
    }
    
    CFMutableArrayRef headers = CFArrayCreateMutable(CFGetAllocator(dependencyScanner), 0, &kCFTypeArrayCallBacks);
    if(headers == nullptr)
    {
        return nullptr;
    }
    
    llvm::StringRef remaining(depStr.c_str() + colonPos + 1);
    llvm::SmallVector<llvm::StringRef, 32> tokens;
    remaining.split(tokens, ' ', -1, false);
    
    CFAllocatorRef allocator = CFGetAllocator(dependencyScanner);
    bool first = true;
    for(llvm::StringRef token : tokens)
    {
        token = token.trim(" \t\n\r\\");
        if(token.empty()) continue;
        if(first) { first = false; continue; }
        if(!dependencyScanner->sysroot.empty() && token.starts_with(dependencyScanner->sysroot)) continue;
        if(!dependencyScanner->resourceDir.empty() && token.starts_with(dependencyScanner->resourceDir)) continue;
        
        std::string tokenStr = token.str();
        CCFileRef file = CCFileCreateWithCString(allocator, tokenStr.c_str(), kCFStringEncodingUTF8);
        if(file == nullptr)
        {
            continue;
        }
        
        CFArrayAppendValue(headers, file);
        
        if(file != nullptr)
        {
            CFRelease(file);
        }
    }
    
    return headers;
}
