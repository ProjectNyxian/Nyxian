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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <cstdlib>
#include <cstdio>
#include <string>
#include <pthread.h>
#include "llvm/Support/raw_ostream.h"
#import <LindChain/Compiler/Compiler.h>
#import <LindChain/Synpush/Synpush.h>

#if JAILBREAK_ENV


extern "C" int shell(NSString *command, uid_t uid, NSArray<NSString *> *env, NSString **output);

#endif /* JAILBREAK_ENV */

// TODO: Might want to extract a header
int CompileObject(int argc,
                  const char **argv,
                  const char *outputFilePath,
                  const char *platformTripple,
                  char **errorStringSet);

@interface Compiler ()

@property (nonatomic,strong) NSArray * _Nonnull flags;
@property (nonatomic,strong) NSString *triple;
@property (nonatomic,strong) NSLock *lock;

@end

@implementation Compiler

///
/// Method that initilizes the more-use Compiler
///
- (instancetype)init:(NSArray*)flags
{
    self = [super init];
    _flags = [flags copy];
    
    NSUInteger index = [_flags indexOfObject:@"-target"];
    _triple = [_flags objectAtIndex:index + 1];
    
    self.lock = [[NSLock alloc] init];
    
    return self;
}

///
/// Method that compiles a object file for a given file path
///
- (int)compileObject:(nonnull NSString*)filePath
          outputFile:(NSString*)outputFilePath
              issues:(NSArray<Synitem*> * * _Nonnull)issues
{
#if !JAILBREAK_ENV
    // Allocating a C array by the given _flags array
    const int argc = (int)[_flags count] + 2;
    char **argv = (char **)malloc(sizeof(char*) * argc);
    argv[0] = strdup("clang");
    argv[1] = strdup([filePath UTF8String]);
    
    // Unconcurrently access _flags and copy them over to our array
    [self.lock lock];
    for(int i = 2; i < argc; i++) argv[i] = strdup([[_flags objectAtIndex:i - 2] UTF8String]);
    [self.lock unlock];

    // Compile and get the resulting integer
    char *errorString = NULL;
    const int result = CompileObject(argc, (const char**)argv, [outputFilePath UTF8String], [_triple UTF8String], &errorString);
    
    // Check if errorString is allocated, if so...
    if(errorString)
    {
        NSString *errorObjCString = [NSString stringWithCString:errorString encoding:NSUTF8StringEncoding];
        *issues = [Synitem OfClangErrorWithString:errorObjCString];
        free(errorString);
    }
    
    // Deallocating the entire C array
    for(int i = 0; i < argc; i++) free(argv[i]);
    free(argv);
    
    return result;
#else
    NSString *command = [NSString stringWithFormat:@"clang %@ -fno-caret-diagnostics -c %@ -o %@", [_flags componentsJoinedByString:@" "], filePath, outputFilePath];
    
    NSString *output = nil;
    
    int retval = shell(command, 501, NULL, &output);
    
    if(output)
    {
        *issues = [Synitem OfClangErrorWithString:output];
    }
    
    return retval;
#endif /* !JAILBREAK_ENV */
}

@end
