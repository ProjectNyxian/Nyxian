/*
 * MIT License
 *
 * Copyright (c) 2026 mach-port-t
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in all
 * copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 */

#include <CoreCompiler/CCBase.h>
#include <CoreCompiler/CCUtils.h>
#include <llvm/Support/Threading.h>
#include <llvm/Support/TargetSelect.h>
#include <llvm/Support/CrashRecoveryContext.h>
#include <swift/Basic/InitializeSwiftModules.h>

CFIndex CCGetMaximumPerformanceCores(void)
{
    return llvm::heavyweight_hardware_concurrency().compute_thread_count();
}

llvm::SmallVector<std::string, 64> CCArrayToStringVector(CFArrayRef array)
{
    llvm::SmallVector<std::string, 64> result;
    CFIndex count = CFArrayGetCount(array);
    result.reserve(count);
    
    for(CFIndex i = 0; i < count; i++)
    {
        CFStringRef str = (CFStringRef)CFArrayGetValueAtIndex(array, i);
        if(str == nullptr)
        {
            continue;
        }
        
        CFIndex len = CFStringGetMaximumSizeForEncoding(CFStringGetLength(str), kCFStringEncodingUTF8) + 1;
        std::string s(len, '\0');
        CFStringGetCString(str, s.data(), len, kCFStringEncodingUTF8);
        s.resize(strlen(s.c_str()));
        result.push_back(std::move(s));
    }
    
    return result;
}

llvm::SmallVector<const char *, 64> StringVectorToCStrings(const llvm::SmallVector<std::string, 64> &vec)
{
    llvm::SmallVector<const char *, 64> result;
    result.reserve(vec.size());
    for(const std::string &s : vec)
    {
        result.push_back(s.c_str());
    }
    return result;
}

static void CCLLVMErrorHandler(void *userData, const char *reason, bool genCrashDiag)
{
    fprintf(stderr, "[CoreCompiler] fatal LLVM error: %s\n", reason);
    abort();
}

void CCInstallLLVMFatalErrorHandler(void)
{
    llvm::install_fatal_error_handler(CCLLVMErrorHandler);
}

__attribute__((constructor))
void llvm_init(void)
{
    LLVMInitializeAArch64TargetInfo();
    LLVMInitializeAArch64Target();
    LLVMInitializeAArch64TargetMC();
    LLVMInitializeAArch64AsmParser();
    LLVMInitializeAArch64AsmPrinter();
    LLVMInitializeAArch64Disassembler();
    llvm::install_fatal_error_handler(CCLLVMErrorHandler);
    llvm::CrashRecoveryContext::Enable();
}
