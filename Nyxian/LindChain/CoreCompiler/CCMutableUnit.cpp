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

#include <LindChain/CoreCompiler/CCMutableUnit.h>
#include <clang/Frontend/ASTUnit.h>
#include <clang/Frontend/CompilerInstance.h>
#include <clang/Tooling/Tooling.h>
#include <clang/Basic/DiagnosticOptions.h>
#include <llvm/Support/raw_ostream.h>
#include <llvm/ADT/StringRef.h>
#include <clang/Basic/LLVM.h>

using namespace clang;
using namespace clang::driver;

static CFTypeID gCCMutableUnitTypeID = _kCFRuntimeNotATypeID;

struct opaque_ccmutableunit {
    CFRuntimeBase _base;
    std::vector<std::string> BaseArgs;
    ASTUnit::RemappedFile file;
    std::unique_ptr<ASTUnit> unit;
};

static void CCMutableUnitFinalize(CFTypeRef cf)
{
    CCMutableUnitRef unit = (CCMutableUnitRef)cf;
    unit->unit.reset();
    if(unit->file.second)
    {
        delete unit->file.second;
    }
    unit->BaseArgs.~vector();
}

static void CCMutableUnitInit(CFTypeRef cf)
{
    CCMutableUnitRef unit = (CCMutableUnitRef)cf;
    new (&unit->BaseArgs) std::vector<std::string>();
    unit->file = ASTUnit::RemappedFile();
    new (&unit->unit) std::unique_ptr<ASTUnit>();
}

static const CFRuntimeClass gCCMutableUnitClass = {
    0,                              /* version */
    "LDEMutableUnit",               /* class name (later for OBJC type) */
    CCMutableUnitInit,              /* init */
    NULL,                           /* copy */
    CCMutableUnitFinalize,          /* finalize */
    NULL,                           /* equal */
    NULL,                           /* hash */
    NULL,                           /* copyFormattingDesc */
    NULL,                           /* copyDebugDesc */
};

CFTypeID CCMutableUnitGetTypeID(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gCCMutableUnitTypeID = _CFRuntimeRegisterClass(&gCCMutableUnitClass);
    });
    return gCCMutableUnitTypeID;
}

CCMutableUnitRef CCMutableUnitCreate(CFAllocatorRef allocator)
{
    return (CCMutableUnitRef)_CFRuntimeCreateInstance(allocator, CCMutableUnitGetTypeID(), sizeof(opaque_ccmutableunit) - sizeof(CFRuntimeBase), nullptr);
}

Boolean CCMutableUnitReparse(CCMutableUnitRef mutableUnit)
{
    if(mutableUnit->BaseArgs.size() == 0)
    {
        /* arguments havent been set */
        return false;
    }
    
    if(mutableUnit->file.second == nullptr)
    {
        /*
         * the file has not been updated,
         * so when the AST unit exists
         * and is non null then that means
         * its still as valid as before.
         */
        return (mutableUnit->unit != nullptr);
    }
    
    /* setting up argument */
    SmallVector<const char *, 64> args;
    for(const std::string &arg : mutableUnit->BaseArgs)
    {
        args.push_back(arg.c_str());
    }
    args.push_back(mutableUnit->file.first.c_str());
    
    auto diags = CompilerInstance::createDiagnostics(new clang::DiagnosticOptions());
    
    SmallVector<ASTUnit::RemappedFile, 4> remaps;
    remaps.push_back(mutableUnit->file);
    ArrayRef<ASTUnit::RemappedFile> remapRef = remaps;
    
    if(mutableUnit->unit == nullptr)
reparse_from_nothing:
    {
        mutableUnit->unit = ASTUnit::LoadFromCommandLine(args.data(),
                                                         args.data() + args.size(),
                                                         std::make_shared<PCHContainerOperations>(),
                                                         diags,
                                                         "",    /* resources comes from arguments */
                                                         /*StorePreamblesInMemory=*/true,
                                                         /*PreambleStoragePath=*/"",
                                                         /*OnlyLocalDecls=*/false,
                                                         clang::CaptureDiagsKind::All,
                                                         remapRef,
                                                         /*RemappedFilesKeepOriginalName=*/true,
                                                         /*PrecompilePreambleAfterNParses=*/0,  // 0 = no preamble precompilation
                                                         clang::TU_Complete,
                                                         /*CacheCodeCompletionResults=*/false,
                                                         /*IncludeBriefComments=*/false,
                                                         /*AllowPCHWithCompilerErrors=*/false,
                                                         clang::SkipFunctionBodiesScope::None,
                                                         /*SingleFileParse=*/false,
                                                         /*UserFilesAreVolatile=*/false,
                                                         /*ForSerialization=*/false,
                                                         /*RetainExcludedConditionalBlocks=*/false,
                                                         /*ModuleFormat=*/std::nullopt,
                                                         nullptr);
    }
    else
    {
        if(mutableUnit->unit->Reparse(std::make_shared<PCHContainerOperations>(), remapRef))
        {
            /*
             * failed reparse, gonna have to
             * parse from 0.
             */
            mutableUnit->unit.reset();
            goto reparse_from_nothing;
        }
    }
    
    bool success = (mutableUnit->unit != nullptr);
    
    if(success)
    {
        /* ASTUnit now owns the MemoryBuffer ptr */
        mutableUnit->file.second = nullptr;
    }
    
    return success;
}

void CCMutableUnitSetArguments(CCMutableUnitRef mutableUnit,
                               CFArrayRef arguments)
{
    if(mutableUnit->unit != nullptr)
    {
        mutableUnit->unit.reset();
    }
    mutableUnit->BaseArgs.clear();
    mutableUnit->BaseArgs.push_back("clang");
    CFIndex count = CFArrayGetCount(arguments);
    for(CFIndex i = 0; i < count; i++)
    {
        CFStringRef arg = (CFStringRef)CFArrayGetValueAtIndex(arguments, i);
        const char *ptr = CFStringGetCStringPtr(arg, kCFStringEncodingUTF8);
        if(ptr)
        {
            mutableUnit->BaseArgs.push_back(ptr);
        }
        else
        {
            char buf[1024];
            CFStringGetCString(arg, buf, sizeof(buf), kCFStringEncodingUTF8);
            mutableUnit->BaseArgs.push_back(buf);
        }
    }
}

void CCMutableUnitSetFileContent(CCMutableUnitRef mutableUnit,
                                 CFURLRef fileURL,
                                 CFDataRef content)
{
    char filepath[PATH_MAX];
    CFURLGetFileSystemRepresentation(fileURL, true, (UInt8*)filepath, sizeof(filepath));
    
    llvm::StringRef contentRef((const char*)CFDataGetBytePtr(content), CFDataGetLength(content));
    std::unique_ptr<llvm::MemoryBuffer> buf = llvm::MemoryBuffer::getMemBufferCopy(contentRef, filepath);
    auto remap = clang::ASTUnit::RemappedFile(filepath, buf.release());
    
    if(mutableUnit->file.second)
    {
        delete mutableUnit->file.second;
    }
    if(!mutableUnit->file.first.empty() && mutableUnit->file.first != remap.first && mutableUnit->unit != nullptr)
    {
        mutableUnit->unit.reset();
    }
    mutableUnit->file = remap;
}

CFURLRef CCMutableUnitGetFileURL(CCMutableUnitRef mutableUnit)
{
    if(mutableUnit->file.first.empty())
    {
        return nullptr;
    }
    CFStringRef fileStr = CFStringCreateWithCString(kCFAllocatorDefault, mutableUnit->file.first.c_str(), kCFStringEncodingUTF8);
    CFURLRef fileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, fileStr, kCFURLPOSIXPathStyle, false);
    CFRelease(fileStr);
    return fileURL;
}

CFIndex CCMutableUnitGetDiagnosticCount(CCMutableUnitRef mutableUnit)
{
    return (mutableUnit->unit == nullptr) ? 0 : mutableUnit->unit->stored_diag_size();
}

CCDiagnosticRef CCDiagnosticCreateFromMutableUnit(CCMutableUnitRef mutableUnit,
                                                  uint64_t index)
{
    if(mutableUnit->unit == nullptr)
    {
        return nullptr;
    }
    
    if(index >= mutableUnit->unit->stored_diag_size())
    {
        return nullptr;
    }
    
    CCDiagnosticType type;
    CCDiagnosticLevel level;
    CFURLRef fileURL = nullptr;
    CCSourceLocation location;
    CFStringRef message;
    
    const StoredDiagnostic &diag = mutableUnit->unit->stored_diag_begin()[index];
    clang::PresumedLoc loc = mutableUnit->unit->getSourceManager().getPresumedLoc(diag.getLocation());
    
    if(loc.isValid())
    {
        if(mutableUnit->file.first == loc.getFilename())
        {
            type = CCDiagnosticTypeTargetFile;
        }
        else
        {
            type = CCDiagnosticTypeFile;
        }
        
        const char *fileName = loc.getFilename();
        CFStringRef fileStr = CFStringCreateWithCString(kCFAllocatorDefault, fileName, kCFStringEncodingUTF8);
        fileURL = CFURLCreateWithFileSystemPath(kCFAllocatorDefault, fileStr, kCFURLPOSIXPathStyle, false);
        CFRelease(fileStr);
        
        location = CCSourceLocationMake(loc.getLine(), loc.getColumn());
    }
    else
    {
        type = CCDiagnosticTypeInternal;
        location = CCSourceLocationZero;
    }
    
    message = CFStringCreateWithCString(kCFAllocatorDefault, diag.getMessage().str().c_str(), kCFStringEncodingUTF8);
    
    switch(diag.getLevel())
    {
        case clang::DiagnosticsEngine::Note:
            level = CCDiagnosticLevelNote;
            break;
        case clang::DiagnosticsEngine::Remark:
            level = CCDiagnosticLevelRemark;
            break;
        case clang::DiagnosticsEngine::Warning:
            level = CCDiagnosticLevelWarning;
            break;
        case clang::DiagnosticsEngine::Error:
            level = CCDiagnosticLevelError;
            break;
        case clang::DiagnosticsEngine::Fatal:
            level = CCDiagnosticLevelFatal;
            break;
        default:
            level = CCDiagnosticLevelNote;
            break;
    }
    
    CCDiagnosticRef result = CCDiagnosticCreate(kCFAllocatorDefault, type, level, fileURL, location, message);
    if(fileURL)
    {
        CFRelease(fileURL);
    }
    CFRelease(message);
    return result;
}
