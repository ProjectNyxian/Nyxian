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

#include <LindChain/CoreCompiler/CCASTUnit.h>
#include <clang/Frontend/ASTUnit.h>
#include <clang/Frontend/CompilerInstance.h>
#include <clang/Tooling/Tooling.h>
#include <clang/Basic/DiagnosticOptions.h>
#include <llvm/Support/raw_ostream.h>
#include <llvm/ADT/StringRef.h>
#include <clang/Basic/LLVM.h>
#include <clang/AST/RecursiveASTVisitor.h>

using namespace clang;
using namespace clang::driver;

static CFTypeID gCCASTUnitTypeID = _kCFRuntimeNotATypeID;

struct opaque_ccastunit {
    CFRuntimeBase _base;
    Boolean isMutable;
    std::vector<std::string> BaseArgs;
    std::unique_ptr<ASTUnit> unit;
    CCFileRef file;
    CFArrayRef diagnostics;
};

static void CCASTUnitFinalize(CFTypeRef cf)
{
    CCMutableASTUnitRef unit = (CCMutableASTUnitRef)cf;
    if(unit->unit != nullptr)
    {
        unit->unit.reset();
    }
    unit->BaseArgs.~vector();
    if(unit->file != nullptr)
    {
        CFRelease(unit->file);
    }
    if(unit->diagnostics != nullptr)
    {
        CFRelease(unit->diagnostics);
    }
}

static void CCASTUnitInit(CFTypeRef cf)
{
    CCMutableASTUnitRef unit = (CCMutableASTUnitRef)cf;
    new (&unit->BaseArgs) std::vector<std::string>();
    new (&unit->unit) std::unique_ptr<ASTUnit>();
    unit->isMutable = true;
    unit->file = nullptr;
    unit->diagnostics = nullptr;
}

static const CFRuntimeClass gCCASTUnitClass = {
    0,                              /* version */
    "LDEASTUnit",                   /* class name (later for OBJC type) */
    CCASTUnitInit,                  /* init */
    NULL,                           /* copy */
    CCASTUnitFinalize,              /* finalize */
    NULL,                           /* equal */
    NULL,                           /* hash */
    NULL,                           /* copyFormattingDesc */
    NULL,                           /* copyDebugDesc */
    NULL,
    NULL,
    0
};

CFTypeID CCASTUnitGetTypeID(void)
{
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        gCCASTUnitTypeID = _CFRuntimeRegisterClass(&gCCASTUnitClass);
    });
    return gCCASTUnitTypeID;
}

Boolean _CCASTUnitRefillDiagnosticArray(CCMutableASTUnitRef mutableUnit)
{
    if(mutableUnit->diagnostics != nullptr)
    {
        return false;
    }
    
    CFAllocatorRef allocator = CFGetAllocator(mutableUnit);
    
    /* now parse the diagnostics */
    CFIndex count = mutableUnit->unit->stored_diag_size();
    CFMutableArrayRef diagnostics = CFArrayCreateMutable(allocator, count, &kCFTypeArrayCallBacks);
    if(diagnostics == nullptr)
    {
        return false;
    }
    
    /* now indice for indice */
    for(CFIndex i = 0; i < count; i++)
    {
        CCDiagnosticType type = CCDiagnosticTypeFile;
        CCDiagnosticLevel level;
        CFURLRef fileURL = nullptr;
        CCSourceLocation location;
        CFStringRef message;
        
        const StoredDiagnostic &diag = mutableUnit->unit->stored_diag_begin()[i];
        clang::PresumedLoc loc = mutableUnit->unit->getSourceManager().getPresumedLoc(diag.getLocation());
        
        if(loc.isValid())
        {
            if(mutableUnit->file != nullptr)
            {
                char filePath[PATH_MAX];
                if(CFURLGetFileSystemRepresentation(CCFileGetFileURL(mutableUnit->file), true, (UInt8*)filePath, sizeof(filePath)))
                {
                    type = (strncmp(filePath, loc.getFilename(), PATH_MAX) == 0) ? CCDiagnosticTypeTargetFile : CCDiagnosticTypeFile;
                }
            }
            
            const char *fileName = loc.getFilename();
            CFStringRef fileStr = CFStringCreateWithCString(allocator, fileName, kCFStringEncodingUTF8);
            fileURL = CFURLCreateWithFileSystemPath(allocator, fileStr, kCFURLPOSIXPathStyle, false);
            CFRelease(fileStr);
            
            location = CCSourceLocationMake(loc.getLine(), loc.getColumn());
        }
        else
        {
            type = CCDiagnosticTypeInternal;
            location = CCSourceLocationZero;
        }
        
        message = CFStringCreateWithCString(allocator, diag.getMessage().str().c_str(), kCFStringEncodingUTF8);
        
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
                level = CCDiagnosticLevelUnknown;
                break;
        }
        
        CCFileSourceLocationRef fileSourceLocation = CCFileSourceLocationCreate(allocator, fileURL, location);
        CCDiagnosticRef result = CCDiagnosticCreate(allocator, type, level, fileSourceLocation, message);
        if(fileURL)
        {
            CFRelease(fileURL);
        }
        CFRelease(message);
        
        CFArrayAppendValue(diagnostics, result);
        CFRelease(result); /* array owns now a reference */
    }
    
    mutableUnit->diagnostics = diagnostics;
    
    return true;
}

CCMutableASTUnitRef CCASTUnitCreateMutable(CFAllocatorRef allocator)
{
    return (CCMutableASTUnitRef)_CFRuntimeCreateInstance(allocator, CCASTUnitGetTypeID(), sizeof(opaque_ccastunit) - sizeof(CFRuntimeBase), nullptr);
}

CC_CXX_EXPORT CCASTUnitRef CCASTUnitCreateWithASTUnit(CFAllocatorRef allocator,
                                                      std::unique_ptr<clang::ASTUnit> astUnit)
{
    if(astUnit == nullptr)
    {
        /* cannot create empty unit */
        return nullptr;
    }
    
    CCMutableASTUnitRef unit = (CCMutableASTUnitRef)_CFRuntimeCreateInstance(allocator, CCASTUnitGetTypeID(), sizeof(opaque_ccastunit) - sizeof(CFRuntimeBase), nullptr);
    unit->unit = std::move(astUnit);
    _CCASTUnitRefillDiagnosticArray(unit);
    
    std::string originalInputFileName = unit->unit->getOriginalSourceFileName().str();
    if(!originalInputFileName.empty())
    {
        const char *originalInputFileNameCStr = originalInputFileName.c_str();
        unit->file = CCFileCreateWithCString(allocator, originalInputFileNameCStr, kCFStringEncodingUTF8);
    }
    
    /* marking immutable, since not a live AST object */
    unit->isMutable = false;
    
    return (CCASTUnitRef)unit;
}

static const char *_CCASTUnitLangFlagForFile(CCFileRef file)
{
    switch(CCFileGetType(file))
    {
        case CCFileTypeC:
            return "c";
        /*
         * MARK: special mapping, due to missing indexing in CoreCompiler for now
         *
         * case CCFileTypeCHeader:
         *    return "c-header";
        */
        case CCFileTypeObjC:
            return "objective-c";
        case CCFileTypeCHeader:
        case CCFileTypeObjCHeader:
            return "objective-c-header";
        case CCFileTypeCXX:
            return "c++";
        case CCFileTypeCXXHeader:
            return "c++-header";
        case CCFileTypeObjCXX:
            return "objective-c++";
        case CCFileTypeObjCXXHeader:
            return "objective-c++-header";
        default:
            return nullptr;
    }
}

Boolean CCASTUnitReparse(CCMutableASTUnitRef mutableUnit)
{
    assert(mutableUnit->isMutable);
    
    /*
     * releasing diagnostics array, because
     * the data it contains is now invalid
     * anyways.
     */
    if(mutableUnit->diagnostics != nullptr)
    {
        CFRelease(mutableUnit->diagnostics);
        
        /* so the data is officially not valid anymore */
        mutableUnit->diagnostics = nullptr;
    }
    
    if(mutableUnit->BaseArgs.size() == 0)
    {
        /* arguments havent been set */
        return false;
    }
    
    /* setting up argument */
    SmallVector<const char *, 64> args;
    for(const std::string &arg : mutableUnit->BaseArgs)
    {
        args.push_back(arg.c_str());
    }
    
    char filePath[PATH_MAX];
    CFURLGetFileSystemRepresentation(CCFileGetFileURL(mutableUnit->file), true, (UInt8*)filePath, sizeof(filePath));
    
    args.push_back(filePath);
    
    auto diags = CompilerInstance::createDiagnostics(new clang::DiagnosticOptions());
    
    SmallVector<ASTUnit::RemappedFile, 4> remaps;
    CFDataRef data = CCFileGetUnsavedData(mutableUnit->file);
    if(data != nullptr)
    {
        llvm::StringRef contentRef((const char*)CFDataGetBytePtr(data), CFDataGetLength(data));
        std::unique_ptr<llvm::MemoryBuffer> buf = llvm::MemoryBuffer::getMemBufferCopy(contentRef, filePath);
        auto remap = clang::ASTUnit::RemappedFile(filePath, buf.release());
        remaps.push_back(remap);
    }
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
    
    if((mutableUnit->unit != nullptr) && !_CCASTUnitRefillDiagnosticArray(mutableUnit))
    {
        return false;
    }
    
    return true;
}

void CCASTUnitSetArguments(CCMutableASTUnitRef mutableUnit,
                           CFArrayRef arguments)
{
    assert(mutableUnit->isMutable);
    
    if(mutableUnit->unit != nullptr)
    {
        mutableUnit->unit.reset();
    }
    mutableUnit->BaseArgs.clear();
    mutableUnit->BaseArgs.push_back("clang");
    
    const char *lang = _CCASTUnitLangFlagForFile(mutableUnit->file);
    if(lang)
    {
        mutableUnit->BaseArgs.push_back("-x");
        mutableUnit->BaseArgs.push_back(lang);
    }
    
    /*
     * silencing those weird linker warnings
     * on live typechecking, which libclang
     * doesn't do automatically, but it should
     * be done automatically to not piss of
     * developers and engineers like me.
     */
    mutableUnit->BaseArgs.push_back("--start-no-unused-arguments");
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
    mutableUnit->BaseArgs.push_back("--end-no-unused-arguments");
}

CC_EXPORT void CCASTUnitSetFile(CCMutableASTUnitRef mutableUnit,
                                CCFileRef file)
{
    assert(mutableUnit->isMutable);
    
    if(mutableUnit->file != nullptr)
    {
        if(!CFEqual(CCFileGetFileURL(mutableUnit->file), CCFileGetFileURL(file)))
        {
            mutableUnit->unit.reset();
        }
        CFRelease(mutableUnit->file);
    }
    mutableUnit->file = (CCFileRef)CFRetain(file);
}

CCFileRef CCASTUnitGetFile(CCASTUnitRef unit)
{
    return unit->file;
}

CCFileRef CCASTUnitCopyFile(CCASTUnitRef unit)
{
    if(unit->file == nullptr)
    {
        return nullptr;
    }
    return CCFileCreateCopy(CFGetAllocator(unit), unit->file);
}

Boolean CCASTUnitErrorOccured(CCASTUnitRef unit)
{
    if(unit->unit == nullptr)
    {
        /*
         * no unit, return the constant
         * that makes the possibility for a
         * programmer to find the mistake of
         * not having parsed anything the most
         * probable.
         */
        return true;
    }
    return unit->unit->getDiagnostics().hasErrorOccurred();
}

class DeclAtLocationVisitor : public RecursiveASTVisitor<DeclAtLocationVisitor> {
public:
    SourceLocation targetLoc;
    SourceManager *SM;
    Decl *found = nullptr;
    
    bool shouldVisitTemplateInstantiations() const { return true; }
    
    bool VisitDeclRefExpr(DeclRefExpr *E)
    {
        if(SM->getSpellingLoc(E->getLocation()) == SM->getSpellingLoc(targetLoc))
        {
            found = E->getDecl();
            return false;
        }
        return true;
    }
    
    bool VisitMemberExpr(MemberExpr *E)
    {
        if(SM->getSpellingLoc(E->getMemberLoc()) == SM->getSpellingLoc(targetLoc))
        {
            found = E->getMemberDecl();
            return false;
        }
        return true;
    }
    
    bool VisitObjCMessageExpr(ObjCMessageExpr *E)
    {
        if(SM->getSpellingLoc(E->getSelectorStartLoc()) == SM->getSpellingLoc(targetLoc))
        {
            found = E->getMethodDecl();
            return false;
        }
        return true;
    }
    
    bool VisitObjCPropertyRefExpr(ObjCPropertyRefExpr *E)
    {
        if(SM->getSpellingLoc(E->getLocation()) == SM->getSpellingLoc(targetLoc))
        {
            if(E->isExplicitProperty())
            {
                found = E->getExplicitProperty();
            }
            return false;
        }
        return true;
    }
    
    bool VisitObjCInterfaceDecl(ObjCInterfaceDecl *D)
    {
        if(D->getSuperClass() &&
           SM->getSpellingLoc(D->getSuperClassLoc()) == SM->getSpellingLoc(targetLoc))
        {
            found = D->getSuperClass()->getDefinition();
            if(!found)
            {
                found = D->getSuperClass();
            }
            return false;
        }
        
        auto locIt = D->protocol_loc_begin();
        for(auto *proto : D->protocols())
        {
            if(SM->getSpellingLoc(*locIt) == SM->getSpellingLoc(targetLoc))
            {
                found = proto->getDefinition();
                if(!found)
                {
                    found = proto;
                }
                return false;
            }
            ++locIt;
        }
        
        return true;
    }
    
    bool VisitObjCCategoryDecl(ObjCCategoryDecl *D)
    {
        if(D->getClassInterface() &&
           SM->getSpellingLoc(D->getLocation()) == SM->getSpellingLoc(targetLoc))
        {
            found = D->getClassInterface()->getDefinition();
            return false;
        }
        return true;
    }
    
    bool VisitObjCImplementationDecl(ObjCImplementationDecl *D)
    {
        if(SM->getSpellingLoc(D->getLocation()) == SM->getSpellingLoc(targetLoc))
        {
            ObjCInterfaceDecl *iface = D->getClassInterface();
            if(iface)
            {
                found = iface->getDefinition();
                return false;
            }
        }
        return true;
    }
    
    bool VisitObjCInterfaceTypeLoc(ObjCInterfaceTypeLoc TL)
    {
        if(SM->getSpellingLoc(TL.getNameLoc()) == SM->getSpellingLoc(targetLoc))
        {
            ObjCInterfaceDecl *iface = TL.getIFaceDecl();
            if(iface)
            {
                found = iface->getDefinition();
                if(!found)
                {
                    found = iface;
                }
                return false;
            }
        }
        return true;
    }
    
    bool VisitNamedDecl(NamedDecl *D)
    {
        if(SM->getSpellingLoc(D->getLocation()) == SM->getSpellingLoc(targetLoc))
        {
            found = D;
            return false;
        }
        return true;
    }
};

CCFileSourceLocationRef CCASTUnitCopyDefinitionAtLocation(CCASTUnitRef unit,
                                                          CCSourceLocation location)
{
    if(unit->unit == nullptr || unit->file == nullptr)
    {
        return nullptr;
    }
    
    char filePath[PATH_MAX];
    if(!CFURLGetFileSystemRepresentation(CCFileGetFileURL(unit->file), true, (UInt8*)filePath, sizeof(filePath)))
    {
        return nullptr;
    }
    
    SourceManager &SM = unit->unit->getSourceManager();
    FileManager &FM = unit->unit->getFileManager();
    
    auto fileEntry = FM.getFile(filePath);
    if(!fileEntry)
    {
        return nullptr;
    }
    
    FileID fileID = SM.translateFile(*fileEntry);
    if(fileID.isInvalid())
    {
        return nullptr;
    }
    
    SourceLocation loc = SM.translateLineCol(fileID, (unsigned int)location.line, (unsigned int)location.column);
    if(loc.isInvalid())
    {
        return nullptr;
    }
    
    DeclAtLocationVisitor visitor;
    visitor.targetLoc = loc;
    visitor.SM = &SM;
    visitor.TraverseAST(unit->unit->getASTContext());
    
    Decl *cursor = visitor.found;
    if(!cursor)
    {
        return nullptr;
    }
    
    Decl *defDecl = nullptr;
    
    /* getting definition (hopefully) */
    if(auto *ID = dyn_cast<ObjCInterfaceDecl>(cursor))
    {
        defDecl = ID->getDefinition();
    }
    else if(auto *PD = dyn_cast<ObjCProtocolDecl>(cursor))
    {
        defDecl = PD->getDefinition();
    }
    else if(auto *TD = dyn_cast<TagDecl>(cursor))
    {
        defDecl = TD->getDefinition();
    }
    else if(auto *FD = dyn_cast<FunctionDecl>(cursor))
    {
        defDecl = FD->getDefinition();
    }
    
    /* last resort */
    if(defDecl == nullptr)
    {
        defDecl = cursor->getCanonicalDecl();
    }
    
    if(!defDecl)
    {
        return nullptr;
    }
    
    SourceLocation defLoc = defDecl->getLocation();
    PresumedLoc presumed = SM.getPresumedLoc(defLoc);
    
    if(presumed.isInvalid())
    {
        return nullptr;
    }
    
    CFAllocatorRef allocator = CFGetAllocator(unit);
    CFStringRef fileStr = CFStringCreateWithCString(allocator, presumed.getFilename(), kCFStringEncodingUTF8);
    CFURLRef fileURL = CFURLCreateWithFileSystemPath(allocator, fileStr, kCFURLPOSIXPathStyle, false);
    CFRelease(fileStr);
    
    CCSourceLocation resultLoc = CCSourceLocationMake(presumed.getLine(), presumed.getColumn());
    CCFileSourceLocationRef result = CCFileSourceLocationCreate(allocator, fileURL, resultLoc);
    CFRelease(fileURL);
    return result;
}

CFArrayRef CCASTUnitCopyDiagnostics(CCASTUnitRef unit)
{
    if(unit->diagnostics == nullptr)
    {
        return nullptr;
    }
    return (CFArrayRef)CFRetain(unit->diagnostics);
}
