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

#include <LindChain/CoreCompiler/CCCompiler.h>
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

CCASTUnitRef CCCompilerJobExecute(CCJobRef job)
{
    assert(job != nullptr);
    assert(CCJobGetType(job) == CCJobTypeCompiler);
    
    CFArrayRef argsArray = CCJobGetArguments(job);
    CFIndex count = CFArrayGetCount(argsArray);

    llvm::SmallVector<std::string, 64> argStorage;
    llvm::SmallVector<const char *, 64> Args;
    argStorage.reserve(count);
    Args.reserve(count);

    for(CFIndex i = 0; i < count; i++)
    {
        CFStringRef s = (CFStringRef)CFArrayGetValueAtIndex(argsArray, i);
        CFIndex len = CFStringGetMaximumSizeForEncoding(CFStringGetLength(s), kCFStringEncodingUTF8) + 1;
        argStorage.push_back(std::string(len, '\0'));
        CFStringGetCString(s, argStorage.back().data(), len, kCFStringEncodingUTF8);
        argStorage.back().resize(strlen(argStorage.back().c_str()));
        Args.push_back(argStorage.back().c_str());
    }
    
    /* setting up clang driver */
    IntrusiveRefCntPtr<DiagnosticsEngine> Diags(new DiagnosticsEngine(llvm::makeIntrusiveRefCnt<DiagnosticIDs>(), llvm::makeIntrusiveRefCnt<DiagnosticOptions>(), new IgnoringDiagConsumer()));
    
    /* creating clang invocation */
    auto CI = std::make_shared<CompilerInvocation>();
    CompilerInvocation::CreateFromArgs(*CI, Args, *Diags);
    
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
    
    return  CCASTUnitCreateWithASTUnit(CFGetAllocator(job), std::unique_ptr<clang::ASTUnit>(ASTUnit));
}
