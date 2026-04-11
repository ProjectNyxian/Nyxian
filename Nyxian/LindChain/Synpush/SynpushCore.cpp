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

struct opaque_synpushunit {
    std::vector<std::string> BaseArgs;
    ASTUnit::RemappedFile file;
    std::unique_ptr<ASTUnit> unit;
};

SPUnit SPUnitCreate(void)
{
    return new (std::nothrow) opaque_synpushunit();
}

void SPUnitDestroy(SPUnit unit)
{
    if(unit->unit != nullptr)
    {
        unit->unit.reset();
    }
    if(unit->file.second)
    {
        delete unit->file.second;
    }
    delete static_cast<opaque_synpushunit *>(unit);
}

bool SPUnitReparse(SPUnit unit)
{
    if(unit->BaseArgs.size() == 0)
    {
        /* arguments havent been set */
        return false;
    }
    
    if(unit->file.second == nullptr)
    {
        /*
         * the file has not been updated,
         * so when the AST unit exists
         * and is non null then that means
         * its still as valid as before.
         */
        return (unit->unit != nullptr);
    }
    
    /* setting up argument */
    SmallVector<const char *, 64> args;
    for(const std::string &arg : unit->BaseArgs)
    {
        args.push_back(arg.c_str());
    }
    args.push_back(unit->file.first.c_str());
    
    auto diags = CompilerInstance::createDiagnostics(new clang::DiagnosticOptions());
    
    SmallVector<ASTUnit::RemappedFile, 4> remaps;
    remaps.push_back(unit->file);
    ArrayRef<ASTUnit::RemappedFile> remapRef = remaps;
    
    if(unit->unit == nullptr)
reparse_from_nothing:
    {
        unit->unit = ASTUnit::LoadFromCommandLine(args.data(),
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
        if(unit->unit->Reparse(std::make_shared<PCHContainerOperations>(), remapRef))
        {
            /*
             * failed reparse, gonna have to
             * parse from 0.
             */
            unit->unit.reset();
            goto reparse_from_nothing;
        }
    }
    
    bool success = (unit->unit != nullptr);
    
    if(success)
    {
        /* ASTUnit now owns the MemoryBuffer ptr */
        unit->file.second = nullptr;
    }
    
    return success;
}

void SPUnitSetArguments(SPUnit unit,
                        int argc,
                        const char **argv)
{
    if(unit->unit != nullptr)
    {
        unit->unit.reset();
    }
    unit->BaseArgs.clear();
    unit->BaseArgs.push_back("clang");
    for(int i = 0; i < argc; i++)
    {
        unit->BaseArgs.push_back(argv[i]);
    }
}

void SPUnitSetFileContent(SPUnit unit,
                          const char *filepath,
                          const char *content,
                          size_t length)
{
    llvm::StringRef contentRef(content, length);
    std::unique_ptr<llvm::MemoryBuffer> buf = llvm::MemoryBuffer::getMemBufferCopy(contentRef, filepath);
    auto remap = clang::ASTUnit::RemappedFile(filepath, buf.release());
    if(unit->file.second)
    {
        delete unit->file.second;
    }
    if(!unit->file.first.empty() && unit->file.first != remap.first && unit->unit != nullptr)
    {
        unit->unit.reset();
    }
    unit->file = remap;
}

uint64_t SPUnitGetDiagnosticCount(SPUnit unit)
{
    return (unit->unit == nullptr) ? 0 : unit->unit->stored_diag_size();
}

SPDiag *SPDiagnosticCreateFromUnit(SPUnit unit,
                                   uint64_t index)
{
    if(unit->unit == nullptr)
    {
        return nullptr;
    }
    
    if(index >= unit->unit->stored_diag_size())
    {
        return nullptr;
    }
    
    SPDiag *syndiag = new (std::nothrow) SPDiag();
    if(syndiag == nullptr)
    {
        return nullptr;
    }
    
    const StoredDiagnostic &diag = unit->unit->stored_diag_begin()[index];
    clang::PresumedLoc loc = unit->unit->getSourceManager().getPresumedLoc(diag.getLocation());
    
    if(loc.isValid())
    {
        if(unit->file.first == loc.getFilename())
        {
            syndiag->type = SPDiagTypeTargetFile;
        }
        else
        {
            syndiag->type = SPDiagTypeFile;
        }
        
        syndiag->filepath = loc.getFilename();
        syndiag->line = loc.getLine();
        syndiag->column = loc.getColumn();
    }
    else
    {
        syndiag->type = SPDiagTypeInternal;
    }
    
    syndiag->message = strdup(diag.getMessage().str().c_str());
    
    switch(diag.getLevel())
    {
        case clang::DiagnosticsEngine::Note:
            syndiag->level = SPDiagLevelNote;
            break;
        case clang::DiagnosticsEngine::Remark:
            syndiag->level = SPDiagLevelRemark;
            break;
        case clang::DiagnosticsEngine::Warning:
            syndiag->level = SPDiagLevelWarning;
            break;
        case clang::DiagnosticsEngine::Error:
            syndiag->level = SPDiagLevelError;
            break;
        case clang::DiagnosticsEngine::Fatal:
            syndiag->level = SPDiagLevelFatal;
            break;
        default:
            syndiag->level = SPDiagLevelUnknown;
            break;
    }
    
    return syndiag;
}

void SPDiagnosticDestroy(SPDiag *syndiag)
{
    if(syndiag->message)
    {
        free((void *)syndiag->message);
    }
    delete static_cast<SPDiag *>(syndiag);
}
