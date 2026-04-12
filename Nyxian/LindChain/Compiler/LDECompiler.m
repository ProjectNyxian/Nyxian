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
    
    const int argc = (int)[flags count];
    char **argv = (char **)malloc(sizeof(char*) * argc);
    for(int i = 0; i < argc; i++) argv[i] = strdup([[flags objectAtIndex:i] UTF8String]);
    
    _svc = CreateScanService(argc, (const char**)argv);
    _cmp = CreateObjectCompiler(argc, (const char**)argv);
    
    for(int i = 0; i < argc; i++) free(argv[i]);
    free(argv);
    
    return self;
}

///
/// Method that compiles a object file for a given file path
///
- (int)compileObject:(nonnull NSString*)filePath
          outputFile:(NSString*)outputFilePath
              issues:(NSArray<LDEDiagnostic*> * * _Nonnull)issues
{
    /* compile and get the resulting integer */
    BOOL didSucceed;
    CCASTUnitRef unit = CompileObject(_cmp, [filePath UTF8String], [outputFilePath UTF8String], &didSucceed);
    if(unit)
    {
        *issues = CFBridgingRelease(CCASTUnitCopyDiagnostics(unit));
        CFRelease(unit);
    }
    return didSucceed ? 0 : 1;
}

- (NSArray<NSString*>*)headersForFilePath:(NSString*)filePath
                                    error:(NSError**)error
{
    dependency_scan_result_t result = ScanDependencies(_svc, [filePath UTF8String]);

    if(result.failed)
    {
        if(error)
        {
            NSString *errMsg = result.errorMsg ? @(result.errorMsg) : @"unknown error";
            NSString *badFile = nil;

            NSRange first = [errMsg rangeOfString:@"'"];
            NSRange last = [errMsg rangeOfString:@"'" options:NSBackwardsSearch];

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
