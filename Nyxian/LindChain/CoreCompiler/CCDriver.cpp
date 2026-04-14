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

#include <LindChain/CoreCompiler/CCDriver.h>
#include <clang/Basic/Diagnostic.h>
#include <clang/Basic/DiagnosticOptions.h>
#include <clang/Basic/SourceManager.h>
#include <clang/CodeGen/CodeGenAction.h>
#include <clang/Driver/Compilation.h>
#include <clang/Driver/Driver.h>
#include <clang/Driver/Tool.h>
#include <clang/Frontend/CompilerInstance.h>
#include <clang/Frontend/CompilerInvocation.h>
#include <clang/Frontend/FrontendDiagnostic.h>
#include <clang/Frontend/TextDiagnosticPrinter.h>
#include <llvm/Support/FileSystem.h>
#include <llvm/Support/ManagedStatic.h>
#include <llvm/Support/Path.h>
#include <llvm/Support/raw_ostream.h>
#include <llvm/Target/TargetMachine.h>
#include <llvm/Support/TargetSelect.h>

using namespace clang;
using namespace clang::driver;

static CFTypeID gCCDriverTypeID = _kCFRuntimeNotATypeID;

struct opaque_ccdriver {
    CFRuntimeBase _base;
    IntrusiveRefCntPtr<DiagnosticsEngine> diags;
    std::unique_ptr<Driver> driver;
    std::unique_ptr<Compilation> compilation;
    llvm::SmallVector<std::string, 64> argStorage;
    void *outputPathCallbackContext;
};

static CFTypeRef CCDriverCopy(CFAllocatorRef allocator,
                              CFTypeRef cf)
{
    return CFRetain(cf);
}

static void CCDriverFinalize(CFTypeRef cf)
{
    CCDriverRef driverRef = (CCDriverRef)cf;
    driverRef->compilation.reset();
    driverRef->driver.reset();
    driverRef->compilation.~unique_ptr<Compilation>();
    driverRef->driver.~unique_ptr<Driver>();
    driverRef->diags.~IntrusiveRefCntPtr<DiagnosticsEngine>();
    driverRef->argStorage.~SmallVector<std::string, 64>();
}

static const CFRuntimeClass gCCDriverClass = {
    0,                              /* version */
    "LDEDriver",                    /* class name (later for OBJC type) */
    NULL,                           /* init */
    CCDriverCopy,                   /* copy */
    CCDriverFinalize,               /* finalize */
    NULL,                           /* equal */
    NULL,                           /* hash */
    NULL,                           /* copyFormattingDesc */
    NULL,                           /* copyDebugDesc */
    NULL,
    NULL,
    0
};

CFTypeID CCDriverGetTypeID(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gCCDriverTypeID = _CFRuntimeRegisterClass(&gCCDriverClass);
    });
    return gCCDriverTypeID;
}

CCDriverRef CCDriverCreate(CFAllocatorRef allocator, CFArrayRef arguments)
{
    assert(arguments != nullptr);
    
    CCDriverRef driverRef = (CCDriverRef)_CFRuntimeCreateInstance(allocator, CCDriverGetTypeID(), sizeof(struct opaque_ccdriver) - sizeof(CFRuntimeBase), NULL);
    if(driverRef == nullptr)
    {
        return nullptr;
    }
    
    CFIndex count = CFArrayGetCount(arguments);
    
    new (&driverRef->argStorage) llvm::SmallVector<std::string, 64>();
    driverRef->argStorage.reserve(count);
    for(CFIndex i = 0; i < count; i++)
    {
        CFStringRef arg = (CFStringRef)CFArrayGetValueAtIndex(arguments, i);
        
        if(CFStringGetLength(arg) == 0)
        {
            continue;
        }
        
        CFIndex len = CFStringGetMaximumSizeForEncoding(CFStringGetLength(arg), kCFStringEncodingUTF8) + 1;
        driverRef->argStorage.push_back(std::string(len, '\0'));
        CFStringGetCString(arg, driverRef->argStorage.back().data(), len, kCFStringEncodingUTF8);
        driverRef->argStorage.back().resize(strlen(driverRef->argStorage.back().c_str()));
    }
    
    driverRef->outputPathCallbackContext = nullptr;
    
    /* setting up clang driver */
    IntrusiveRefCntPtr<DiagnosticsEngine> Diags(new DiagnosticsEngine(llvm::makeIntrusiveRefCnt<DiagnosticIDs>(), llvm::makeIntrusiveRefCnt<DiagnosticOptions>(), new IgnoringDiagConsumer()));
    
    /* building compilation */
    new (&driverRef->diags) IntrusiveRefCntPtr<DiagnosticsEngine>();
    new (&driverRef->driver) std::unique_ptr<Driver>();
    new (&driverRef->compilation) std::unique_ptr<Compilation>();
    
    driverRef->diags = Diags;
    
    try
    {
        driverRef->driver = std::make_unique<Driver>("clang", "", *Diags);
    }
    catch (...)
    {
        CFRelease(driverRef);
        return nullptr;
    }
    
    return driverRef;
}

CFArrayRef CCDriverCopyJobs(CCDriverRef driver)
{
    llvm::SmallVector<const char *, 64> Args;
    Args.reserve(driver->argStorage.size() + 2);
    Args.push_back("clang");
    Args.push_back("-fuse-ld=lld"); /* forcing LLD instead of GNU's eww linker */
    for(const std::string &s : driver->argStorage)
    {
        Args.push_back(s.c_str());
    }
    
    driver->compilation.reset(driver->driver->BuildCompilation(Args));
    
    if(driver->compilation == nullptr)
    {
        return nullptr;
    }
    
    /* getting jobs */
    const auto &Jobs = driver->compilation->getJobs();
    
    CFMutableArrayRef jobsArray = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
    
    /* checking job properties */
    for(auto &Job : Jobs)
    {
        if(!isa<Command>(Job))
        {
            continue;
        }
        
        const Command &Cmd = cast<Command>(Job);
        
        CCJobRef jobRef = CCJobCreate(kCFAllocatorDefault, driver, &Cmd);
        if(jobRef != nullptr)
        {
            CFArrayAppendValue(jobsArray, jobRef);
            CFRelease(jobRef);
        }
    }
    
    return jobsArray;
}

void CCDriverSetOutputPathCallback(CCDriverRef driver,
                                   CCOutputPathCallback callback,
                                   void *context)
{
    driver->outputPathCallbackContext = context;
    
    if(callback == nullptr)
    {
        driver->driver->OutputPathOverride = std::nullopt;
        return;
    }
    
    driver->driver->OutputPathOverride = [callback, context](const clang::driver::JobAction &JA,
                                                             const char *baseInput,
                                                             llvm::StringRef boundArch) -> std::string
    {
        if(!clang::isa<clang::driver::CompileJobAction>(JA) &&
           !clang::isa<clang::driver::AssembleJobAction>(JA))
        {
            return "";
        }
        
        const char *result = callback(baseInput, context);
        if(!result)
        {
            return "";
        }
        return std::string(result);
    };
}

void *CCDriverGetOutputPathCallbackContext(CCDriverRef driver)
{
    return driver->outputPathCallbackContext;
}
