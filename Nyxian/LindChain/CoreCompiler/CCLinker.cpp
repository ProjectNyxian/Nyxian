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

#include <LindChain/CoreCompiler/CCLinker.h>
#include <lld/Common/Driver.h>
#include <lld/Common/ErrorHandler.h>
#include <llvm/ADT/ArrayRef.h>
#include <llvm/Support/raw_ostream.h>
#include <llvm/Support/CrashRecoveryContext.h>
#include <lld/Common/CommonLinkerContext.h>

namespace lld {
namespace macho {

bool link(llvm::ArrayRef<const char *> args, llvm::raw_ostream &stdoutOS,
          llvm::raw_ostream &stderrOS, bool exitEarly, bool disableOutput);

} // namespace macho
} // namespace lld

CC_EXPORT Boolean CCLinkerJobExecute(CCJobRef job,
                                     CFArrayRef *outDiagnostics)
{
    assert(job != nullptr);
    assert(CCJobGetType(job) == CCJobTypeLinker);
    
    CFArrayRef argsArray = CCJobGetArguments(job);
    CFIndex count = CFArrayGetCount(argsArray);

    llvm::SmallVector<std::string, 64> argStorage;
    llvm::SmallVector<const char *, 64> Args;
    argStorage.reserve(count);
    Args.reserve(count);
    
    argStorage.push_back("ld64.lld");   /* have to inject */
    Args.push_back(argStorage.back().c_str());

    for(CFIndex i = 0; i < count; i++)
    {
        CFStringRef s = (CFStringRef)CFArrayGetValueAtIndex(argsArray, i);
        CFIndex len = CFStringGetMaximumSizeForEncoding(CFStringGetLength(s), kCFStringEncodingUTF8) + 1;
        argStorage.push_back(std::string(len, '\0'));
        CFStringGetCString(s, argStorage.back().data(), len, kCFStringEncodingUTF8);
        argStorage.back().resize(strlen(argStorage.back().c_str()));
        Args.push_back(argStorage.back().c_str());
    }
    
    std::vector<LDDiagnostic> diagnostics;
    int retCode;
    
    llvm::CrashRecoveryContext CRC;
    CRC.RunSafely([&]{
        const lld::DriverDef drivers[] = {
            {lld::Darwin, &lld::macho::link},
        };
        
        lld::Result result = lld::lldMain(Args, llvm::nulls(), llvm::nulls(), drivers, [&diagnostics](const LDDiagnostic &diag) {
            diagnostics.push_back(diag);
        });
        retCode = result.retCode;
        
        lld::CommonLinkerContext::destroy();
    });
    
    if(outDiagnostics != nullptr)
    {
        /* process error returns */
        CFMutableArrayRef result = CFArrayCreateMutable(kCFAllocatorDefault, diagnostics.size(), &kCFTypeArrayCallBacks);
        if(result == nullptr)
        {
            return retCode == 0;
        }
        
        for(auto it = diagnostics.begin(); it != diagnostics.end(); ++it)
        {
            CCDiagnosticRef diagnosticRef = CCDiagnosticCreate(kCFAllocatorDefault, CCDiagnosticTypeInternal, (it->kind == LDDiagnostic::Kind::Error) ? CCDiagnosticLevelError : CCDiagnosticLevelWarning, nullptr, CCSourceLocationZero, CFStringCreateWithCString(kCFAllocatorDefault, it->message.c_str(), kCFStringEncodingUTF8));
            if(diagnosticRef != nullptr)
            {
                CFArrayAppendValue(result, diagnosticRef);
                CFRelease(diagnosticRef);
            }
        }
        
        *outDiagnostics = result;
    }
    
    return retCode == 0;
}
