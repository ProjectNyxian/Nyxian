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
    std::string resourcesDir;
    ASTUnit::RemappedFile file;
    std::unique_ptr<ASTUnit> unit;
};

void SPCCreateUnit(synpushcore_t spc)
{
    /* setting up argument */
    SmallVector<const char *, 64> args;
    for(const std::string &arg : spc->BaseArgs)
    {
        args.push_back(arg.c_str());
    }
    args.push_back(spc->file.first.c_str());
    
    auto diags = CompilerInstance::createDiagnostics(new clang::DiagnosticOptions());
    
    std::unique_ptr<clang::ASTUnit> errAST;
    
    SmallVector<ASTUnit::RemappedFile, 4> remaps;
    remaps.push_back(spc->file);
    ArrayRef<ASTUnit::RemappedFile> remapRef = remaps;
    
    if(spc->unit != nullptr)
    {
        spc->unit = ASTUnit::LoadFromCommandLine(args.data(),
                                                 args.data() + args.size(),
                                                 std::make_shared<PCHContainerOperations>(),
                                                 diags,
                                                 spc->resourcesDir,          // ResourceFilesPath — important, can't be empty
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
                                                 &errAST);
        
        if(!spc->unit && errAST)
        {
            for(auto it = errAST->stored_diag_begin();
                it != errAST->stored_diag_end(); ++it)
            {
                llvm::errs() << it->getMessage() << "\n";
            }
        }
    }
    else
    {
        spc->unit->Reparse(std::make_shared<PCHContainerOperations>(), remapRef);
    }
}

void SPCDestroyUnit(synpushcore_t spc)
{
    spc->unit.reset();
    spc->unit = nullptr;
}

synpushcore_t SPCCreateCore(int argc, const char **argv)
{
    auto *spc = new opaque_synpushcore();
    spc->BaseArgs.push_back("clang");
    for(int i = 0; i < argc; i++)
    {
        spc->BaseArgs.push_back(argv[i]);
    }
    return spc;
}

void SPCFreeCore(synpushcore_t spc)
{
    delete static_cast<opaque_synpushcore *>(spc);
}

void SPCUpdateArguments(synpushcore_t spc,
                        int argc,
                        const char **argv)
{
    SPCDestroyUnit(spc);
    spc->BaseArgs.clear();
    spc->BaseArgs.push_back("clang");
    for(int i = 0; i < argc; i++)
    {
        spc->BaseArgs.push_back(argv[i]);
    }
}

void SPCUpdateFileContent(synpushcore_t spc,
                          const char *filepath,
                          const char *content)
{
    std::unique_ptr<llvm::MemoryBuffer> buf = llvm::MemoryBuffer::getMemBufferCopy(content, filepath);
    spc->file = clang::ASTUnit::RemappedFile(filepath, buf.release());
}

static const char *levelStr(clang::DiagnosticsEngine::Level lvl) {
    switch (lvl) {
        case clang::DiagnosticsEngine::Note: return "note";
        case clang::DiagnosticsEngine::Remark: return "remark";
        case clang::DiagnosticsEngine::Warning: return "warning";
        case clang::DiagnosticsEngine::Error: return "error";
        case clang::DiagnosticsEngine::Fatal: return "fatal";
        default: return "unknown";
    }
}

uint64_t SPCDiagnosticCount(synpushcore_t spc)
{
    return spc->unit->stored_diag_size();
}

synpushdiag_t SPCDiagnosticGet(synpushcore_t spc,
                               uint64_t index)
{
    const StoredDiagnostic &diag = spc->unit->stored_diag_begin()[index];
    clang::PresumedLoc loc = spc->unit->getSourceManager().getPresumedLoc(diag.getLocation());
    
    synpushdiag_t syndiag = {};
    
    if(loc.isValid())
    {
        if(spc->file.first == loc.getFilename())
        {
            syndiag.type = SynpushTypeTargetFile;
        }
        else
        {
            syndiag.type = SynpushTypeFile;
        }
        
        syndiag.filepath = loc.getFilename();
        syndiag.line = loc.getLine();
        syndiag.column = loc.getColumn();
    }
    else
    {
        syndiag.type = SynpushTypeInternal;
    }
    
    syndiag.message = strdup(diag.getMessage().str().c_str());
    
    return syndiag;
}

void SPCDiagnosticDestroy(synpushdiag_t syndiag)
{
    if(syndiag.message)
    {
        free((void *)syndiag.message);
        syndiag.message = nullptr;
    }
}
