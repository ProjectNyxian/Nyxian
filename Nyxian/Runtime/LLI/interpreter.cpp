///
/// Welcome to my own JITless LLVMbased Clang
///
/// Fuck you other developers that close the source of ur overpriced coding apps, lick my ass madeline btw
///

#include <TargetConditionals.h>

#include "clang/Basic/DiagnosticOptions.h"
#include "clang/CodeGen/CodeGenAction.h"
#include "clang/Driver/Compilation.h"
#include "clang/Driver/Driver.h"
#include "clang/Driver/Tool.h"
#include "clang/Frontend/CompilerInstance.h"
#include "clang/Frontend/CompilerInvocation.h"
#include "clang/Frontend/FrontendDiagnostic.h"
#include "clang/Frontend/TextDiagnosticPrinter.h"
#include "llvm/ADT/SmallString.h"
#include "llvm/IR/DataLayout.h"
#include "llvm/IR/Mangler.h"
#include "llvm/IR/Module.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/Host.h"
#include "llvm/Support/ManagedStatic.h"
#include "llvm/Support/Path.h"
#include "llvm/Support/TargetSelect.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Target/TargetMachine.h"
#include "llvm/ExecutionEngine/SectionMemoryManager.h"
#include "llvm/ExecutionEngine/Interpreter.h"
#include "llvm/ExecutionEngine/GenericValue.h"
#include "llvm/IR/Verifier.h"
#include <Runtime/Hook/stdfd.h>
#include <Runtime/LLI/ErrorHandler.h>
#include <Runtime/LLI/Linker.h>
#include <stdio.h>

const char* getIncludePath(void);

using namespace clang;
using namespace clang::driver;

std::string GetExecutablePath(const char *Argv0, void *MainAddr) {
  return llvm::sys::fs::getMainExecutable(Argv0, MainAddr);
}

llvm::ExitOnError ExitOnErr;

int clangInterpret(int argc, const char **argv/*, llvm::raw_ostream &errorOutputStream*/) {
    std::string errorString;
    llvm::raw_string_ostream errorOutputStream(errorString);
    
    void *MainAddr = (void*) (intptr_t) GetExecutablePath;
    std::string Path = GetExecutablePath(argv[0], MainAddr);
    IntrusiveRefCntPtr<DiagnosticOptions> DiagOpts = new DiagnosticOptions();
    TextDiagnosticPrinter *DiagClient =
    new TextDiagnosticPrinter(errorOutputStream, &*DiagOpts);
    
    IntrusiveRefCntPtr<DiagnosticIDs> DiagID(new DiagnosticIDs());
    DiagnosticsEngine Diags(DiagID, &*DiagOpts, DiagClient);
    
    const std::string TripleStr = "arm64-apple-darwin";
    
    llvm::Triple T(TripleStr);
    
    if (T.isOSBinFormatCOFF())
        T.setObjectFormat(llvm::Triple::ELF);
    
    ExitOnErr.setBanner("clang interpreter");
    
    Driver TheDriver(Path, T.str(), Diags);
    TheDriver.setTitle("clang interpreter");
    TheDriver.setCheckInputsExist(false);
    
    // FIXME: This is a hack to try to force the driver to do something we can
    // recognize. We need to extend the driver library to support this use model
    // (basically, exactly one input, and the operation mode is hard wired).
    SmallVector<const char *, 16> Args(argv, argv + argc);
    Args.push_back(getIncludePath());
    Args.push_back("-fsyntax-only");
    Args.push_back("-Wno-nullability-completeness");
    Args.push_back("-Wno-nullability");
    std::unique_ptr<Compilation> C(TheDriver.BuildCompilation(Args));
    if (!C)
        return 0;
    
    const driver::JobList &Jobs = C->getJobs();
    if (Jobs.size() != 1 || !isa<driver::Command>(*Jobs.begin())) {
        SmallString<256> Msg;
        llvm::raw_svector_ostream OS(Msg);
        Jobs.Print(OS, "; ", true);
        Diags.Report(diag::err_fe_expected_compiler_job) << OS.str();
        return 1;
    }
    
    const driver::Command &Cmd = cast<driver::Command>(*Jobs.begin());
    if (llvm::StringRef(Cmd.getCreator().getName()) != "clang") {
        Diags.Report(diag::err_fe_expected_clang_command);
        return 1;
    }
    
    const llvm::opt::ArgStringList &CCArgs = Cmd.getArguments();
    std::unique_ptr<CompilerInvocation> CI(new CompilerInvocation);
    CompilerInvocation::CreateFromArgs(*CI, CCArgs, Diags);
    
    if (CI->getHeaderSearchOpts().Verbose) {
        errorOutputStream << "clang invocation:\n";
        Jobs.Print(errorOutputStream, "\n", true);
        errorOutputStream << "\n";
    }
    
    CompilerInstance Clang;
    Clang.setInvocation(std::move(CI));
    
    Clang.createDiagnostics(DiagClient, false);
    if (!Clang.hasDiagnostics())
        return 1;
    
    if (Clang.getHeaderSearchOpts().UseBuiltinIncludes &&
        Clang.getHeaderSearchOpts().ResourceDir.empty())
        Clang.getHeaderSearchOpts().ResourceDir =
        CompilerInvocation::GetResourcesPath(argv[0], MainAddr);
    
    std::unique_ptr<CodeGenAction> Act(new EmitLLVMOnlyAction());
    
    if (!Clang.ExecuteAction(*Act))
        return 1;

    errorString = errorOutputStream.str();
    fprintf(stdfd_out_fp, "%s\n", errorString.c_str());
    fflush(stdfd_out_fp);
    
    llvm::InitializeNativeTarget();
    llvm::InitializeNativeTargetAsmPrinter();
    
    int Res = 255;
    std::unique_ptr<llvm::LLVMContext> Ctx(Act->takeLLVMContext());
    std::unique_ptr<llvm::Module> Module = Act->takeModule();
    
    if(llvm::verifyModule(*Module, &llvm::errs())) {
        return 1;
    }
    
    llvm::Module* module = Module.get();
    
    if(setjmp(JumpBuf) == 1)
        return 1;
    
    llvm::install_fatal_error_handler(NyxLLVMErrorHandler);
    
    if (Module) {
        llvm::Function *MainFunc = Module->getFunction("main");
        
        llvm::ExecutionEngine *Interpreter = llvm::EngineBuilder(std::move(Module))
            .setEngineKind(llvm::EngineKind::Interpreter)
            .create();
        
        if (!Interpreter) {
            fprintf(stdfd_out_fp, "Failed to create the LLVM Interpreter.\n");
            fflush(stdfd_out_fp);
            return 1;
        }
        
        if (!MainFunc) {
            fprintf(stdfd_out_fp, "No main function found in the LLVM IR.\n");
            fflush(stdfd_out_fp);
            return 1;
        }
        
        if(!NyxianLLVMLinker(Interpreter, module, llvm::errs()))
            return 1;
        
        std::vector<llvm::GenericValue> Args;
        
        /// Womp Womp Womp
        llvm::GenericValue Result = Interpreter->runFunction(MainFunc, Args);
    }
    
    llvm::remove_fatal_error_handler();
    
    return Res;
}
