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

#import <LindChain/Decompiler/Decompiler.h>
#include <iostream>
#include <dlfcn.h>

std::vector<std::string> disassembleARM64iOS(uint8_t* code, size_t size);

@implementation Decompiler

+ (NSString*)decompileBinary:(uint8_t*)code withSize:(size_t)size
{
    std::vector<std::string> array = disassembleARM64iOS(code, size);
    NSMutableString *result = [NSMutableString string];
    for (size_t i = 0; i < array.size(); i++)
        [result appendFormat:@"%@\n", [NSString stringWithUTF8String:array[i].c_str()]];
    return result;
    
    return NULL;
}

+ (NSString*)getDecompiledCodeBuffer:(UInt64)markAddress
{
    Dl_info info;
    dladdr((void*)markAddress, &info);
    size_t instrSize = 4;
    
    std::vector<std::string> array = disassembleARM64iOS((uint8_t*)info.dli_saddr, 0);
    
    NSMutableString *result = [NSMutableString string];
    for (size_t i = 0; i < array.size(); i++) {
        uint64_t currAddr = (uint64_t)(((uintptr_t)info.dli_saddr) + i * instrSize);
        NSString *prefix = (currAddr == markAddress) ? @"-> " : @"   ";
        [result appendFormat:@"%@%@\n", prefix, [NSString stringWithUTF8String:array[i].c_str()]];
    }
    
    return result;
}

@end
