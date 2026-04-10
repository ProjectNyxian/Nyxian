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

#include <LindChain/Synpush/SynpushCore.h>
#include "clang/Frontend/ASTUnit.h"
#include "clang/Frontend/CompilerInstance.h"
#include "clang/Tooling/Tooling.h"
#include "clang/Basic/DiagnosticOptions.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/ADT/StringRef.h"
#include "clang/Basic/LLVM.h"
#include <stdlib.h>

using namespace clang;
using namespace clang::driver;

struct opaque_synpushcore {
    std::vector<std::string> BaseArgs;
    ASTUnit::RemappedFile file;
    std::unique_ptr<ASTUnit> unit;
};

bool SPCreateUnit(spcore_t spc)
{
    if(spc->file.second == nullptr)
    {
        /* the file has not been updated */
        return false;
    }
    
    /* setting up argument */
    SmallVector<const char *, 64> args;
    for(const std::string &arg : spc->BaseArgs)
    {
        args.push_back(arg.c_str());
    }
    args.push_back(spc->file.first.c_str());
    
    auto diags = CompilerInstance::createDiagnostics(new clang::DiagnosticOptions());
    
    SmallVector<ASTUnit::RemappedFile, 4> remaps;
    remaps.push_back(spc->file);
    ArrayRef<ASTUnit::RemappedFile> remapRef = remaps;
    
    if(spc->unit == nullptr)
reparse_from_nothing:
    {
        spc->unit = ASTUnit::LoadFromCommandLine(args.data(),
                                                 args.data() + args.size(),
                                                 std::make_shared<PCHContainerOperations>(),
                                                 diags,
                                                 "",
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
        if(spc->unit->Reparse(std::make_shared<PCHContainerOperations>(), remapRef))
        {
            SPDestroyUnit(spc);
            goto reparse_from_nothing;
        }
    }
    
    bool success = (spc->unit != nullptr);
    
    if(success)
    {
        /* ASTUnit now owns the MemoryBuffer ptr */
        spc->file.second = nullptr;
    }
    
    return success;
}

void SPDestroyUnit(spcore_t spc)
{
    spc->unit.reset();
    spc->unit = nullptr;
}

spcore_t SPCreateCore(int argc, const char **argv)
{
    auto *spc = new opaque_synpushcore();
    spc->BaseArgs.push_back("clang");
    for(int i = 0; i < argc; i++)
    {
        spc->BaseArgs.push_back(argv[i]);
    }
    return spc;
}

void SPFreeCore(spcore_t spc)
{
    if(spc->unit != nullptr)
    {
        SPDestroyUnit(spc);
    }
    if(spc->file.second)
    {
        delete spc->file.second;
    }
    delete static_cast<opaque_synpushcore *>(spc);
}

void SPUpdateArguments(spcore_t spc,
                       int argc,
                       const char **argv)
{
    SPDestroyUnit(spc);
    spc->BaseArgs.clear();
    spc->BaseArgs.push_back("clang");
    for(int i = 0; i < argc; i++)
    {
        spc->BaseArgs.push_back(argv[i]);
    }
}

void SPUpdateFileContent(spcore_t spc,
                         const char *filepath,
                         const char *content,
                         size_t length)
{
    llvm::StringRef contentRef(content, length);
    std::unique_ptr<llvm::MemoryBuffer> buf = llvm::MemoryBuffer::getMemBufferCopy(contentRef, filepath);
    auto remap = clang::ASTUnit::RemappedFile(filepath, buf.release());
    if(spc->file.second)
    {
        delete spc->file.second;
    }
    if(!spc->file.first.empty() && spc->file.first != remap.first && spc->unit != nullptr)
    {
        SPDestroyUnit(spc);
    }
    spc->file = remap;
}

uint64_t SPDiagnosticCount(spcore_t spc)
{
    return (spc->unit == nullptr) ? 0 : spc->unit->stored_diag_size();
}

spdiag_t SPDiagnosticGet(spcore_t spc,
                         uint64_t index)
{
    const StoredDiagnostic &diag = spc->unit->stored_diag_begin()[index];
    clang::PresumedLoc loc = spc->unit->getSourceManager().getPresumedLoc(diag.getLocation());
    
    spdiag_t syndiag = {};
    
    if(loc.isValid())
    {
        if(spc->file.first == loc.getFilename())
        {
            syndiag.type = SPDiagTypeTargetFile;
        }
        else
        {
            syndiag.type = SPDiagTypeFile;
        }
        
        syndiag.filepath = loc.getFilename();
        syndiag.line = loc.getLine();
        syndiag.column = loc.getColumn();
    }
    else
    {
        syndiag.type = SPDiagTypeInternal;
    }
    
    syndiag.message = strdup(diag.getMessage().str().c_str());
    
    switch(diag.getLevel())
    {
        case clang::DiagnosticsEngine::Note:
            syndiag.level = SPDiagLevelNote;
            break;
        case clang::DiagnosticsEngine::Remark:
            syndiag.level = SPDiagLevelRemark;
            break;
        case clang::DiagnosticsEngine::Warning:
            syndiag.level = SPDiagLevelWarning;
            break;
        case clang::DiagnosticsEngine::Error:
            syndiag.level = SPDiagLevelError;
            break;
        case clang::DiagnosticsEngine::Fatal:
            syndiag.level = SPDiagLevelFatal;
            /* fall through */
        default:
            break;
    }
    
    return syndiag;
}

void SPDiagnosticDestroy(spdiag_t syndiag)
{
    if(syndiag.message)
    {
        free((void *)syndiag.message);
        syndiag.message = nullptr;
    }
}
