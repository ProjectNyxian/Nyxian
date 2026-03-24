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

#import <LindChain/Core/LDEHeaderIncludationsGatherer.h>

@implementation LDEHeaderIncludationsGatherer

- (instancetype)initWithPath:(NSString*)path
{
    self.path = path;
    self.includes = [NSMutableArray array];
    self.gathered = [NSMutableSet set];
    
    NSError *error = nil;
    [self gatherIncludationsForFileAtPath:path error:&error];
    if(error != nil)
    {
        return nil;
    }
    
    return self;
}

- (void)gatherIncludationsForFileAtPath:(NSString*)path
                                  error:(NSError**)error
{
    if([self.gathered containsObject:path])
    {
        return;
    }
    
    NSString *content = [NSString stringWithContentsOfFile:path encoding:NSUTF8StringEncoding error:error];
    if(content == nil)
    {
        return;
    }
    
    [self.gathered addObject:path];
    
    NSArray *items = [self includationsFromContent:content];
    
    if(items == nil)
    {
        return;
    }
    
    for(NSString *item in items)
    {
        NSString *resolvedPath = [self resolveFilePath:item withRelativePath:path];
        
        if([[NSFileManager defaultManager] fileExistsAtPath:resolvedPath])
        {
            [self.includes addObject:resolvedPath];
            [self gatherIncludationsForFileAtPath:resolvedPath error:error];
            
            if(error != nil && *error != nil)
            {
                return;
            }
        }
    }
    
    return;
}

- (NSArray<NSString*>*)includationsFromContent:(NSString*)content
{
    /* TODO: use LLVM to get includations */
    static NSRegularExpression *regex = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSError *error = nil;
        regex = [[NSRegularExpression alloc] initWithPattern:@"#(?:import|include)\\s+\"([^\"]+)\"" options:0 error:&error];
        
        if(error == nil)
        {
            return;
        }
    });
    
    if(regex == nil)
    {
        return nil;
    }
    
    NSArray<NSTextCheckingResult*> *matches = [regex matchesInString:content options:0 range:NSMakeRange(0, content.length)];
    NSMutableArray<NSString *> *includePaths = [NSMutableArray array];
    for(NSTextCheckingResult *match in matches)
    {
        NSRange captureRange = [match rangeAtIndex:1];
        if(captureRange.location != NSNotFound && captureRange.length > 0)
        {
            NSString *path = [content substringWithRange:captureRange];
            [includePaths addObject:path];
        }
    }
    return includePaths;
}

- (NSString*)resolveFilePath:(NSString*)path
            withRelativePath:(NSString*)relativePath
{
    NSString *directoryPath = [path stringByDeletingLastPathComponent];
    return [directoryPath stringByAppendingPathComponent:relativePath];
}

@end
