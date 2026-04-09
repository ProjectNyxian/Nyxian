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

#import <LindChain/Linker/LDELinker.h>
#include "lld/Common/Driver.h"
#include "lld/Common/ErrorHandler.h"
#include "llvm/ADT/ArrayRef.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Support/CrashRecoveryContext.h"
#include "lld/Common/CommonLinkerContext.h"

namespace lld {
namespace macho {

bool link(llvm::ArrayRef<const char *> args, llvm::raw_ostream &stdoutOS,
          llvm::raw_ostream &stderrOS, bool exitEarly, bool disableOutput);

} // namespace macho
} // namespace lld

@implementation LDELinker

+ (int)link:(NSMutableArray*)flags errorString:(NSString **)error
{
    const int argc = (int)[flags count] + 1;
    char **argv = (char **)malloc(sizeof(char*) * argc);
    argv[0] = strdup("ld64.lld");
    for(int i = 1; i < argc; i++) argv[i] = strdup([[flags objectAtIndex:i - 1] UTF8String]);
    
    int retCode = -1;
    std::string outBuffer;
    std::string errBuffer;
    
    llvm::CrashRecoveryContext CRC;
    llvm::CrashRecoveryContext::Enable();
    
    CRC.RunSafely([&]{
        llvm::ArrayRef<const char*> args(argv, argc);
        llvm::raw_string_ostream outStream(outBuffer);
        llvm::raw_string_ostream errStream(errBuffer);

        const lld::DriverDef drivers[] = {
            {lld::Darwin, &lld::macho::link},
        };
        
        lld::Result result = lld::lldMain(args, outStream, errStream, drivers);
        
        outStream.flush();
        errStream.flush();
        retCode = result.retCode;
        
        lld::CommonLinkerContext::destroy();
    });

    if(!errBuffer.empty() && error != nil)
    {
        *error = [NSString stringWithCString:errBuffer.c_str() encoding:NSUTF8StringEncoding];
    }

    for(int i = 0; i < argc; i++) free(argv[i]);
    free(argv);

    return retCode;
}

@end
