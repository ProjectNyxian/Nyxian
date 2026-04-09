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

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <pthread.h>
#import <LindChain/Compiler/LDECompiler.h>
#import <LindChain/Synpush/Synpush.h>
#include <LindChain/Compiler/LDEObjectCompiler.h>
#include <LindChain/Compiler/LDEDependencyScanner.h>

@interface Compiler ()

@property (nonatomic,strong) NSArray * _Nonnull flags;
@property (nonatomic,strong) NSString *triple;
@property (nonatomic,strong) NSLock *lock;

@end

@implementation Compiler {
    dependency_scan_service_t _svc;
    object_compiler_t _cmp;
}

///
/// Method that initilizes the more-use Compiler
///
- (instancetype)init:(NSArray*)flags
{
    self = [super init];
    _flags = [flags copy];
    
    NSUInteger index = [_flags indexOfObject:@"-target"];
    if(index != NSNotFound)
    {
        _triple = [_flags objectAtIndex:index + 1];
    }
    else
    {
        _triple = @"arm64-apple-ios14.0";
    }
    
    self.lock = [[NSLock alloc] init];
    
    _svc = CreateScanService();
    
    const int argc = (int)[_flags count];
    char **argv = (char **)malloc(sizeof(char*) * argc);
    for(int i = 0; i < argc; i++) argv[i] = strdup([[_flags objectAtIndex:i] UTF8String]);
    
    _cmp = CreateObjectCompiler([_triple UTF8String], argc, (const char**)argv);
    
    for(int i = 0; i < argc; i++) free(argv[i]);
    free(argv);
    
    return self;
}

///
/// Method that compiles a object file for a given file path
///
- (int)compileObject:(nonnull NSString*)filePath
          outputFile:(NSString*)outputFilePath
              issues:(NSArray<Synitem*> * * _Nonnull)issues
{
    /* compile and get the resulting integer */
    char *errorString = NULL;
    const int result = CompileObject(_cmp, [filePath UTF8String], [outputFilePath UTF8String], &errorString);
    
    /*
     * check if errorString is allocated, if so...
     * TODO: as RFFI information is included in LLVM we can make our own diagnostics engine which we can use to efficiently get the errors them selves, not requiring us to change the diagniostic options forcefully
     */
    if(errorString)
    {
        NSString *errorObjCString = [NSString stringWithCString:errorString encoding:NSUTF8StringEncoding];
        *issues = [Synitem OfClangErrorWithString:errorObjCString];
        free(errorString);
    }
    
    return result;
}

- (NSArray<NSString*>*)headersForFilePath:(NSString*)filePath
                                    error:(NSError**)error
{
    const int argc = (int)[_flags count] + 2;
    char **argv = (char **)malloc(sizeof(char*) * argc);
    argv[0] = strdup("clang");
    argv[1] = strdup([filePath UTF8String]);
    
    [self.lock lock];
    for(int i = 2; i < argc; i++) argv[i] = strdup([[_flags objectAtIndex:i - 2] UTF8String]);
    [self.lock unlock];
    
    dependency_scan_result_t result = ScanDependencies(_svc, argc, (const char**)argv);
    
    for(int i = 0; i < argc; i++) free(argv[i]);
    free(argv);

    if(result.failed)
    {
        if(error)
        {
            NSString *errMsg = result.errorMsg ? @(result.errorMsg) : @"unknown error";
            NSString *badFile = nil;

            NSRange first = [errMsg rangeOfString:@"'"];
            NSRange last  = [errMsg rangeOfString:@"'" options:NSBackwardsSearch];

            if(first.location != NSNotFound && first.location != last.location)
            {
                badFile = [errMsg substringWithRange:NSMakeRange(first.location + 1, last.location - first.location - 1)];
            }

            NSMutableDictionary *info = [NSMutableDictionary new];
            info[NSLocalizedDescriptionKey] = errMsg;

            if(badFile)
            {
                info[@"LDEBadInclude"] = badFile;
            }

            *error = [NSError errorWithDomain:@"com.cr4zy.nyxian.ldecompiler" code:1 userInfo:info];
        }

        FreeScanResult(result);
        return nil;
    }

    NSMutableArray<NSString *> *headers = [[NSMutableArray alloc] init];
    for(int i = 0; i < result.count; i++)
    {
        [headers addObject:@(result.headers[i])];
    }
    
    FreeScanResult(result);
    return [headers copy];
}

- (void)dealloc
{
    FreeObjectCompiler(_cmp);
    FreeScanService(_svc);
}

@end
