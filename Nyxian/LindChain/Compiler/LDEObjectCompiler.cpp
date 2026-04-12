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

#include <LindChain/Compiler/LDEObjectCompiler.h>
#include "clang/Basic/Diagnostic.h"
#include "clang/Basic/DiagnosticOptions.h"
#include "clang/Basic/SourceManager.h"
#include "clang/CodeGen/CodeGenAction.h"
#include "clang/Driver/Compilation.h"
#include "clang/Driver/Driver.h"
#include "clang/Driver/Tool.h"
#include "clang/Frontend/CompilerInstance.h"
#include "clang/Frontend/CompilerInvocation.h"
#include "clang/Frontend/FrontendDiagnostic.h"
#include "clang/Frontend/TextDiagnosticPrinter.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/ManagedStatic.h"
#include "llvm/Support/Path.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Target/TargetMachine.h"
#include "llvm/Support/TargetSelect.h"

using namespace clang;
using namespace clang::driver;

struct opaque_compiler {
    std::vector<std::string> BaseArgs;
};

extern "C" {

object_compiler_t CreateObjectCompiler(int argc,
                                       const char **argv)
{
    auto *compiler = new opaque_compiler();
    compiler->BaseArgs.push_back("clang");
    for(int i = 0; i < argc; i++)
    {
        compiler->BaseArgs.push_back(argv[i]);
    }
    return compiler;
}

void FreeObjectCompiler(object_compiler_t cmp)
{
    delete static_cast<opaque_compiler *>(cmp);
}

CCASTUnitRef CompileObject(object_compiler_t cmp,
                           const char *inputFilePath,
                           const char *outputFilePath,
                           bool *didSucceed)
{
    /* setting up argument */
    SmallVector<const char *, 64> Args;
    for(const std::string &arg : cmp->BaseArgs)
    {
        Args.push_back(arg.c_str());
    }
    Args.push_back(inputFilePath);
    Args.push_back("-c");
    Args.push_back("-o");
    Args.push_back(outputFilePath);
    
    /* setting up clang driver */
    IntrusiveRefCntPtr<DiagnosticsEngine> Diags(new DiagnosticsEngine(llvm::makeIntrusiveRefCnt<DiagnosticIDs>(), llvm::makeIntrusiveRefCnt<DiagnosticOptions>()));
    Driver TheDriver("clang", "", *Diags);
    
    /* building compilation */
    std::unique_ptr<Compilation> C(TheDriver.BuildCompilation(Args));
    
    /* null pointer check */
    if(C == NULL)
    {
        /* setting error string */
        if(didSucceed) *didSucceed = false;
        return nullptr;
    }
    
    /* getting jobs */
    const auto &Jobs = C->getJobs();
    
    /* checking job properties */
    if(Jobs.size() != 1 ||
       !isa<Command>(*Jobs.begin()))
    {
        /* too many */
        llvm::SmallString<256> Msg;
        llvm::raw_svector_ostream OS(Msg);
        Jobs.Print(OS, "; ", true);
        if(didSucceed) *didSucceed = false;
        return nullptr;
    }
    
    /* getting command */
    const auto &Cmd = cast<Command>(*Jobs.begin());
    
    /* checking if its clang */
    if(Cmd.getCreator().getName() != StringRef("clang"))
    {
        /* its not */
        Diags->Report(diag::err_fe_expected_clang_command);
        if(didSucceed) *didSucceed = false;
        return nullptr;
    }
    
    /* getting ccargs */
    const auto &CCArgs = Cmd.getArguments();
    
    /* creating clang invocation */
    auto CI = std::make_shared<CompilerInvocation>();
    CompilerInvocation::CreateFromArgs(*CI, CCArgs, *Diags);
    
    /*
     * disabling free
     *
     * this is very important to prevent memory leak, clang is usually
     * designed to run in a one hit way, but this is a iOS app so it
     * cannot run in one hit.
     */
    CI->getFrontendOpts().DisableFree = false;
    
    /* compiling */
    auto Act = std::make_unique<EmitObjAction>();
    
    ASTUnit *ASTUnit = ASTUnit::LoadFromCompilerInvocationAction(
        CI,
        std::make_shared<PCHContainerOperations>(),
        Diags,
        Act.release(),
        nullptr,
        true,
        "",
        false,
        CaptureDiagsKind::All
    );
    
    if(didSucceed) *didSucceed = ASTUnit != nullptr && !ASTUnit->getDiagnostics().hasErrorOccurred();
    
    /* creating error string */
    return CCASTUnitCreateWithASTUnit(kCFAllocatorDefault, std::unique_ptr<clang::ASTUnit>(ASTUnit));
}

}
