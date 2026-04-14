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

#include <LindChain/CoreCompiler/CCJob.h>
#include <LindChain/CoreCompiler/CCDriver.h>
#include <clang/Driver/Job.h>
#include <llvm/ADT/StringSet.h>
#include <llvm/Support/Path.h>
#include <llvm/Support/FileSystem.h>

static CFTypeID gCCJobTypeID = _kCFRuntimeNotATypeID;

struct opaque_ccjob {
    CFRuntimeBase _base;
    CCDriverRef driver;
    const clang::driver::Command *Cmd;
    CFArrayRef input;
    CFArrayRef output;
};

static CFTypeRef CCJobCopy(CFAllocatorRef allocator,
                           CFTypeRef cf)
{
    return CFRetain(cf);
}

static void CCJobFinalize(CFTypeRef cf)
{
    CCJobRef jobRef = (CCJobRef)cf;
    CFRelease(jobRef->driver);
    if(jobRef->input != nullptr)
    {
        CFRelease(jobRef->input);
    }
    if(jobRef->output != nullptr)
    {
        CFRelease(jobRef->output);
    }
}

static const CFRuntimeClass gCCJobClass = {
    0,                              /* version */
    "LDEJob",                       /* class name (later for OBJC type) */
    NULL,                           /* init */
    CCJobCopy,                      /* copy */
    CCJobFinalize,                  /* finalize */
    NULL,                           /* equal */
    NULL,                           /* hash */
    NULL,                           /* copyFormattingDesc */
    NULL,                           /* copyDebugDesc */
    NULL,
    NULL,
    0
};

CFTypeID CCJobGetTypeID(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gCCJobTypeID = _CFRuntimeRegisterClass(&gCCJobClass);
    });
    return gCCJobTypeID;
}

CCJobRef CCJobCreate(CFAllocatorRef allocator,
                     CFTypeRef driver,
                     const clang::driver::Command *Cmd)
{
    assert(driver != nullptr);
    
    CCJobRef jobRef = (CCJobRef)_CFRuntimeCreateInstance(allocator, CCJobGetTypeID(), sizeof(struct opaque_ccjob) - sizeof(CFRuntimeBase), NULL);
    if(jobRef == nullptr)
    {
        return nullptr;
    }
    
    jobRef->driver = (CCDriverRef)CFRetain(driver);
    jobRef->Cmd = Cmd;
    
    /* parse output */
    CFMutableArrayRef outputArray = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
    for(const std::string &filename : Cmd->getOutputFilenames())
    {
        CFStringRef str = CFStringCreateWithCString(kCFAllocatorDefault, filename.c_str(), kCFStringEncodingUTF8);
        CFURLRef url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, str, kCFURLPOSIXPathStyle, false);
        CFRelease(str);
        CFArrayAppendValue(outputArray, url);
        CFRelease(url);
    }
    jobRef->output = outputArray;
    
    /* parse input */
    CFMutableArrayRef inputArray = CFArrayCreateMutable(kCFAllocatorDefault, 0, &kCFTypeArrayCallBacks);
    for(const clang::driver::InputInfo &II : Cmd->getInputInfos())
    {
        if(!II.isFilename())
        {
            continue;
        }
        CFStringRef str = CFStringCreateWithCString(kCFAllocatorDefault, II.getFilename(), kCFStringEncodingUTF8);
        CFURLRef url = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, str, kCFURLPOSIXPathStyle, false);
        CFRelease(str);
        CFArrayAppendValue(inputArray, url);
        CFRelease(url);
    }
    jobRef->input = inputArray;
    
    return jobRef;
}

CCJobType CCJobGetType(CCJobRef job)
{
    const clang::driver::Action &source = job->Cmd->getSource();
    
    if(clang::isa<clang::driver::CompileJobAction>(source))
    {
        return CCJobTypeCompiler;
    }
    else if(clang::isa<clang::driver::LinkJobAction>(source))
    {
        return CCJobTypeLinker;
    }
    else if(clang::isa<clang::driver::AssembleJobAction>(source))
    {
        return CCJobTypeAssembler;
    }
    else if(clang::isa<clang::driver::BackendJobAction>(source))
    {
        return CCJobTypeBackend;
    }
    else
    {
        return CCJobTypeUnknown;
    }
}

static CFStringRef _CCJobCopyPathFromArrayElement(CFTypeRef element)
{
    if(element == nullptr)
    {
        return nullptr;
    }
    
    /* stored as CFURLRef */
    if(CFGetTypeID(element) == CFURLGetTypeID())
    {
        CFURLRef url = (CFURLRef)element;
        CFStringRef path = CFURLCopyFileSystemPath(url, kCFURLPOSIXPathStyle);
        if(path != nullptr)
        {
            return path;
        }
        
        /* fallback: strip file:// prefix from absolute string */
        CFStringRef abs = CFURLGetString(url);
        if(abs == nullptr)
        {
            return nullptr;
        }
        if(CFStringHasPrefix(abs, CFSTR("file://")))
        {
            CFIndex len = CFStringGetLength(abs);
            return CFStringCreateWithSubstring(kCFAllocatorDefault, abs, CFRangeMake(7, len - 7));
        }
        return nullptr;
    }
    
    /* stored as CFStringRef */
    if(CFGetTypeID(element) == CFStringGetTypeID())
    {
        return (CFStringRef)CFRetain(element);
    }
    
    return nullptr;
}

CFArrayRef CCJobCopyArguments(CCJobRef job)
{
    if(job == nullptr || job->Cmd == nullptr)
    {
        return nullptr;
    }
    
    const llvm::opt::ArgStringList &Args = job->Cmd->getArguments();
    
    /* build set of original input paths to strip */
    llvm::StringSet<> originalInputs;
    for(const clang::driver::InputInfo &II : job->Cmd->getInputInfos())
    {
        if(II.isFilename() && II.getFilename() != nullptr)
        {
            originalInputs.insert(II.getFilename());
        }
    }
    
    /* build set of original output paths to strip */
    llvm::StringSet<> originalOutputs;
    for(const std::string &f : job->Cmd->getOutputFilenames())
    {
        if(!f.empty())
        {
            originalOutputs.insert(f);
        }
    }
    
    CFMutableArrayRef result = CFArrayCreateMutable(kCFAllocatorDefault, Args.size(), &kCFTypeArrayCallBacks);
    if(result == nullptr)
    {
        return nullptr;
    }
    
    bool skipNext = false;
    for(auto it = Args.begin(); it != Args.end(); ++it)
    {
        const char *arg = *it;
        if(arg == nullptr)
        {
            continue;
        }
        
        /* skip value token of a stripped -o */
        if(skipNext)
        {
            skipNext = false;
            continue;
        }
        
        /* strip -o <original_output> entirely */
        if(strcmp(arg, "-o") == 0)
        {
            auto next = std::next(it);
            if(next != Args.end() && *next != nullptr && originalOutputs.count(*next))
            {
                skipNext = true;
                continue;
            }
            
            /* -o pointing at something we don't own... pass through as is */
            CFStringRef s = CFStringCreateWithCString(kCFAllocatorDefault, arg, kCFStringEncodingUTF8);
            if(s)
            {
                CFArrayAppendValue(result, s);
                CFRelease(s);
            }
            continue;
        }
        
        /* strip original input positionals */
        if(originalInputs.count(arg))
        {
            continue;
        }
        
        CFStringRef s = CFStringCreateWithCString(kCFAllocatorDefault, arg, kCFStringEncodingUTF8);
        if(s)
        {
            CFArrayAppendValue(result, s);
            CFRelease(s);
        }
    }
    
    /* readd output paths */
    CFIndex outputCount = job->output ? CFArrayGetCount(job->output) : 0;
    for(CFIndex i = 0; i < outputCount; i++)
    {
        CFTypeRef element = CFArrayGetValueAtIndex(job->output, i);
        CFStringRef path = _CCJobCopyPathFromArrayElement(element);
        if(path == nullptr)
        {
            continue;
        }
        
        CFArrayAppendValue(result, CFSTR("-o"));
        CFArrayAppendValue(result, path);
        CFRelease(path);
    }
    
    /* readd input paths */
    CFIndex inputCount = job->input ? CFArrayGetCount(job->input) : 0;
    for(CFIndex i = 0; i < inputCount; i++)
    {
        CFTypeRef element = CFArrayGetValueAtIndex(job->input, i);
        CFStringRef path = _CCJobCopyPathFromArrayElement(element);
        if(path == nullptr)
        {
            continue;
        }
        CFArrayAppendValue(result, path);
        CFRelease(path);
    }
    
    return result;
}

CFArrayRef CCJobGetInput(CCJobRef job)
{
    return job->input;
}

CFArrayRef CCJobGetOutput(CCJobRef job)
{
    return job->output;
}

void CCJobSetInput(CCJobRef job, CFArrayRef input)
{
    if(job->input != nullptr)
    {
        CFRelease(job->input);
    }
    job->input = (CFArrayRef)CFRetain(input);
}

void CCJobSetOutput(CCJobRef job, CFArrayRef output)
{
    if(job->output != nullptr)
    {
        CFRelease(job->output);
    }
    job->output = (CFArrayRef)CFRetain(output);
}
