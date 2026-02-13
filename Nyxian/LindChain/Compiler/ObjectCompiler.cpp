/*
 Copyright (C) 2025 cr4zyengineer

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

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

int CompileObject(int argc,
                  const char **argv,
                  const char *outputFilePath,
                  const char *platformTriple,
                  char **errorStringSet)
{
    /* error string setup */
    std::string errorString;
    llvm::raw_string_ostream errorOutputStream(errorString);

    /* setting up diagnostic options */
    DiagnosticOptions DiagOpts;
    DiagOpts.ShowColors = false;
    DiagOpts.ShowLevel = true;
    DiagOpts.ShowOptionNames = false;
    DiagOpts.MessageLength = 0;
    DiagOpts.ShowSourceRanges = false;
    DiagOpts.ShowPresumedLoc = false;
    DiagOpts.ShowCarets = false;
    
    /* setting up diagnostic engine */
    auto DiagClient = std::make_unique<TextDiagnosticPrinter>(errorOutputStream, DiagOpts);
    auto DiagID = llvm::makeIntrusiveRefCnt<DiagnosticIDs>();
    DiagnosticsEngine Diags(DiagID, DiagOpts, DiagClient.get());
    
    /* setting up platform triple */
    llvm::Triple TargetTriple(platformTriple);
    
    /* setting up clang driver */
    Driver TheDriver(argv[0], TargetTriple.str(), Diags);

    /* setting up argument */
    SmallVector<const char *, 64> Args;
    Args.reserve(argc + 3);             /* reserving arguments */
    Args.assign(argv, argv + argc);     /* filling args */
    Args.push_back("-c");
    Args.push_back("-o");
    Args.push_back(outputFilePath);

    /* building compilation */
    std::unique_ptr<Compilation> C(TheDriver.BuildCompilation(Args));
    
    /* null pointer check */
    if(C == NULL)
    {
        /* setting error string */
        *errorStringSet = strdup(errorString.c_str());
        return 1;
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
        *errorStringSet = strdup(Msg.c_str());
        return 1;
    }

    /* getting command */
    const auto &Cmd = cast<Command>(*Jobs.begin());
    
    /* checking if its clang */
    if(Cmd.getCreator().getName() != StringRef("clang"))
    {
        /* its not */
        Diags.Report(diag::err_fe_expected_clang_command);
        *errorStringSet = strdup(errorString.c_str());
        return 1;
    }

    /* getting ccargs */
    const auto &CCArgs = Cmd.getArguments();
    
    /* creating clang invocation */
    auto CI = std::make_shared<CompilerInvocation>();
    CompilerInvocation::CreateFromArgs(*CI, CCArgs, Diags);

    /*
     * disabling free
     *
     * this is very important to prevent memory leak, clang is usually
     * designed to run in a one hit way, but this is a iOS app so it
     * cannot run in one hit.
     */
    CI->getFrontendOpts().DisableFree = false;
    
    /* creating clang instance */
    CompilerInstance Clang(CI);
    auto VFS = llvm::vfs::getRealFileSystem();
    Clang.createDiagnostics(*VFS, DiagClient.release(), false);
    
    /* hopefully this check is successful */
    if(!Clang.hasDiagnostics())
    {
        /* failed :c */
        *errorStringSet = strdup("Failed to create diagnostics");
        return 1;
    }

    /* compiling */
    auto Act = std::make_unique<EmitObjAction>();
    bool success = Clang.ExecuteAction(*Act);
    
    /* creating error string */
    *errorStringSet = strdup(errorString.c_str());
    return !success || Clang.getDiagnostics().hasErrorOccurred();
}
