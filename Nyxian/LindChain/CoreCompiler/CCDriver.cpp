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
    CFArrayRef jobs;
};

static CFTypeRef CCDriverCopy(CFAllocatorRef allocator,
                              CFTypeRef cf)
{
    return CFRetain(cf);
}

static void CCDriverFinalize(CFTypeRef cf)
{
    CCDriverRef driverRef = (CCDriverRef)cf;
    CFRelease(driverRef->jobs);
}

static CFStringRef CCDriverCopyFormattingDesc(CFTypeRef cf,
                                              CFDictionaryRef options)
{
    CCDriverRef driverRef = (CCDriverRef)cf;
    return CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("%@"), driverRef->jobs);
}

static CFStringRef CCDriverCopyDebugDesc(CFTypeRef cf)
{
    CCDriverRef driverRef = (CCDriverRef)cf;
    return CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("<CCDriver %p: jobs=%@>"), cf, driverRef->jobs);
}

static const CFRuntimeClass gCCDriverClass = {
    0,                              /* version */
    "LDEDriver",                    /* class name (later for OBJC type) */
    NULL,                           /* init */
    CCDriverCopy,                   /* copy */
    CCDriverFinalize,               /* finalize */
    NULL,                           /* equal */
    NULL,                           /* hash */
    CCDriverCopyFormattingDesc,     /* copyFormattingDesc */
    CCDriverCopyDebugDesc,          /* copyDebugDesc */
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

static CCJobType CCJobTypeFromCommand(const Command &Cmd)
{
    const llvm::opt::ArgStringList &Args = Cmd.getArguments();
    if(!Args.empty() && llvm::StringRef(Args[0]) == "-cc1")
    {
        return CCJobTypeCompiler;
    }

    return CCJobTypeLinker;
}

CCDriverRef CCDriverCreate(CFAllocatorRef allocator, CFArrayRef arguments)
{
    assert(arguments != nullptr);
    
    CCDriverRef driverRef = (CCDriverRef)_CFRuntimeCreateInstance(allocator, CCDriverGetTypeID(), sizeof(struct opaque_ccdriver) - sizeof(CFRuntimeBase), NULL);
    if(driverRef == nullptr)
    {
        return nullptr;
    }
    
    SmallVector<std::string, 64> ArgStorage;
    SmallVector<const char *, 64> Args;

    Args.push_back("clang");
    Args.push_back("-fuse-ld=lld"); /* forcing LLD instead of GNU's eww linker */

    CFIndex count = CFArrayGetCount(arguments);
    for(CFIndex i = 0; i < count; i++)
    {
        CFStringRef arg = (CFStringRef)CFArrayGetValueAtIndex(arguments, i);
        const char *ptr = CFStringGetCStringPtr(arg, kCFStringEncodingUTF8);
        if(ptr)
        {
            Args.push_back(ptr);
        }
        else
        {
            ArgStorage.push_back(std::string(1024, '\0'));
            CFStringGetCString(arg, ArgStorage.back().data(), 1024, kCFStringEncodingUTF8);
            ArgStorage.back().resize(strlen(ArgStorage.back().c_str()));
            Args.push_back(ArgStorage.back().c_str());
        }
    }
    
    /* setting up clang driver */
    IntrusiveRefCntPtr<DiagnosticsEngine> Diags(new DiagnosticsEngine(llvm::makeIntrusiveRefCnt<DiagnosticIDs>(), llvm::makeIntrusiveRefCnt<DiagnosticOptions>(), new IgnoringDiagConsumer()));
    Driver TheDriver("clang", "", *Diags);
    
    /* building compilation */
    std::unique_ptr<Compilation> C(TheDriver.BuildCompilation(Args));
    
    /* null pointer check */
    if(C == NULL)
    {
        return nullptr;
    }
    
    /* getting jobs */
    const auto &Jobs = C->getJobs();
    
    CFMutableArrayRef jobs = CFArrayCreateMutable(kCFAllocatorDefault, count, &kCFTypeArrayCallBacks);
    
    /* checking job properties */
    for(auto &Job : Jobs)
    {
        if(!isa<Command>(Job))
        {
            continue;
        }
        
        const Command &Cmd = cast<Command>(Job);
        const llvm::opt::ArgStringList &Args = Cmd.getArguments();
        
        CFMutableArrayRef cmdArgs = CFArrayCreateMutable(kCFAllocatorDefault, Args.size(), &kCFTypeArrayCallBacks);
        for(const char *Arg : Args)
        {
            CFStringRef argStr = CFStringCreateWithCString(kCFAllocatorDefault, Arg, kCFStringEncodingUTF8);
            CFArrayAppendValue(cmdArgs, argStr);
            CFRelease(argStr);
        }
        
        CCJobRef job = CCJobCreate(kCFAllocatorDefault, CCJobTypeFromCommand(Cmd), cmdArgs);
        if(job != nullptr)
        {
            CFArrayAppendValue(jobs, job);
        }
        CFRelease(cmdArgs);
    }
    
    driverRef->jobs = jobs;
    return driverRef;
}

CFArrayRef CCDriverGetJobs(CCDriverRef driver)
{
    return driver->jobs;
}

CFArrayRef CCDriverCopyJobs(CCDriverRef driver)
{
    return (CFArrayRef)CFRetain(driver->jobs);
}
