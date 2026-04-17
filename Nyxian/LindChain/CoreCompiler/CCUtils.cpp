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

#include <LindChain/CoreCompiler/CCBase.h>
#include <LindChain/CoreCompiler/CCUtils.h>
#include <llvm/Support/Threading.h>
#include <llvm/Support/TargetSelect.h>
#include <llvm/Support/CrashRecoveryContext.h>

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

static void NyxLLVMErrorHandler(void *userData, const char *reason, bool genCrashDiag)
{
    fprintf(stderr, "[LindChain] fatal LLVM error: %s\n", reason);
    abort();
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
    llvm::install_fatal_error_handler(NyxLLVMErrorHandler);
    llvm::CrashRecoveryContext::Enable();
}
