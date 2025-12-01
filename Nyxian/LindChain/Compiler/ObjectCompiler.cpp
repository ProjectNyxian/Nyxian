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
                  const char *platformTripple,
                  char **errorStringSet)
{
    std::string errorString;
    llvm::raw_string_ostream errorOutputStream(errorString);

    auto DiagOpts = llvm::makeIntrusiveRefCnt<DiagnosticOptions>();
    
    DiagOpts->ShowColors = false;
    DiagOpts->ShowLevel = true;
    DiagOpts->ShowOptionNames = false;
    DiagOpts->MessageLength = 0;
    DiagOpts->ShowSourceRanges = false;
    DiagOpts->ShowPresumedLoc = false;
    DiagOpts->ShowCarets = false;
    
    auto DiagClient = std::make_unique<TextDiagnosticPrinter>(errorOutputStream, &*DiagOpts);
    auto DiagID = llvm::makeIntrusiveRefCnt<DiagnosticIDs>();
    DiagnosticsEngine Diags(DiagID, &*DiagOpts, DiagClient.get());
    
    llvm::Triple TargetTriple(platformTripple);
    
    Driver TheDriver(argv[0], TargetTriple.str(), Diags);

    SmallVector<const char *, 16> Args(argv, argv + argc);
    Args.push_back("-fsyntax-only");

    std::unique_ptr<Compilation> C(TheDriver.BuildCompilation(Args));
    
    if(!C)
        return 0;

    // FIXME: Crash in here
    const JobList &Jobs = C->getJobs();
    if(Jobs.size() != 1 || !isa<Command>(*Jobs.begin()))
    {
        llvm::SmallString<256> Msg;
        llvm::raw_svector_ostream OS(Msg);
        Jobs.Print(OS, "; ", true);
        puts(Msg.c_str());
        return 1;
    }

    const Command &Cmd = cast<Command>(*Jobs.begin());
    if(std::strcmp(Cmd.getCreator().getName(), "clang") != 0)
    {
        Diags.Report(diag::err_fe_expected_clang_command);
        return 1;
    }

    const auto &CCArgs = Cmd.getArguments();
    auto CI = std::make_unique<CompilerInvocation>();
    CompilerInvocation::CreateFromArgs(*CI, CCArgs, Diags);

    CI->getFrontendOpts().DisableFree = false;
    CI->getFrontendOpts().OutputFile = outputFilePath;

    CompilerInstance Clang;
    Clang.setInvocation(std::move(CI));
    Clang.createDiagnostics(DiagClient.release(), false);
    if(!Clang.hasDiagnostics())
        return 1;

    auto Act = std::make_unique<EmitObjAction>();
    
    Clang.ExecuteAction(*Act);
    
    *errorStringSet = strdup(errorString.c_str());

    return Clang.getDiagnostics().hasErrorOccurred();
}
