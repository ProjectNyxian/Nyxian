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

#import <LindChain/Linker/Linker.h>
#include "lld/Common/Driver.h"
#include "lld/Common/ErrorHandler.h"
#include "llvm/ADT/ArrayRef.h"
#include "llvm/Support/raw_ostream.h"

extern "C" void ls_printf(const char *format, ...);

#if JAILBREAK_ENV

extern "C" {

int shell(NSString *command, uid_t uid, NSArray<NSString *> *env, NSString **output);

}

#endif /* JAILBREAK_ENV */

namespace lld {
namespace macho {

bool link(llvm::ArrayRef<const char *> args, llvm::raw_ostream &stdoutOS,
          llvm::raw_ostream &stderrOS, bool exitEarly, bool disableOutput);

} // namespace macho
} // namespace lld

@implementation Linker

- (instancetype)init
{
    self = [super init];
    return self;
}

- (int)ld64:(NSMutableArray*)flags
{
#if !JAILBREAK_ENV
    // Allocating a C array by the given _flags array
    const int argc = (int)[flags count] + 1;
    char **argv = (char **)malloc(sizeof(char*) * argc);
    argv[0] = strdup("ld64.lld");
    for(int i = 1; i < argc; i++) argv[i] = strdup([[flags objectAtIndex:i - 1] UTF8String]);
    
    // Creating a ArrayRef for LLVM
    llvm::ArrayRef<const char*> args(argv, argc);
    
    // Creating a errBuffer
    std::string errBuffer;
    llvm::raw_string_ostream errStream(errBuffer);
    
    // Definining the drivers
    const lld::DriverDef drivers[] = {
        {lld::Darwin, &lld::macho::link},
    };
    
    // Link!
    lld::Result result = lld::lldMain(args, llvm::outs(), errStream, drivers);
    
    // Flusing the error stram and priting it
    errStream.flush();
    
    const char *str = errBuffer.c_str();
    if(str) _error = [NSString stringWithCString:errBuffer.c_str() encoding:NSUTF8StringEncoding];
    
    // Deallocating the entire C array
    for(int i = 0; i < argc; i++) free(argv[i]);
    free(argv);
    
    return result.retCode;
#else
    NSString *command = [NSString stringWithFormat:@"ld %@", [flags componentsJoinedByString:@" "]];
    
    /* Todo: add a way to retrieve the error string to process it */
    return shell(command, 501, NULL, NULL);
    
    return -1;
#endif /* !JAILBREAK_ENV*/
}

@end
