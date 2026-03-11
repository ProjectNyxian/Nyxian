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

#import <LindChain/Core/LDEFilesFinder.h>

NSArray<NSString*> *LDEFilesFinder(NSString *searchPath,
                                   NSSet<NSString*> *searchExtensions,
                                   NSSet<NSString*> *ignorePaths)
{
    NSMutableArray *foundFiles = [[NSMutableArray alloc] init];
    
    NSError *error = nil;
    NSArray<NSString*> *subPaths = [[NSFileManager defaultManager] subpathsOfDirectoryAtPath:searchPath error:&error];
    if(error) return foundFiles;
    
    for(NSString *relativePath in subPaths)
    {
        NSString *fullPath = [searchPath stringByAppendingFormat:@"/%@", relativePath];
        
        BOOL isDir = NO;
        if([[NSFileManager defaultManager] fileExistsAtPath:fullPath isDirectory:&isDir] &&
            !isDir  &&
            [searchExtensions containsObject: [relativePath pathExtension]] &&
           ![ignorePaths containsObject:relativePath])
        {
            [foundFiles addObject:fullPath];
        }
    }
    
    return foundFiles;
}
