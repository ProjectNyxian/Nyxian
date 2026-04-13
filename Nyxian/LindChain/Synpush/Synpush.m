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

#import <LindChain/Synpush/Synpush.h>
#import <LindChain/Compiler/LDEASTUnit.h>
#import <LindChain/Compiler/LDEFile.h>
#import <pthread.h>
#import <string.h>
#import <strings.h>

#pragma mark - SynpushServer

@interface SynpushServer () {
    pthread_mutex_t _mutex;
    
    LDEMutableASTUnit *_unit;
    LDEMutableFile *_file;
}
@end

@implementation SynpushServer

- (instancetype)init:(NSString*)filepath
{
    self = [super init];
    if(!self) return nil;
    
    /* initilizing step numero uno */
    NSURL *fileURL = [NSURL fileURLWithPath:filepath];
    _file = [LDEMutableFile mutableFileWithFileURL:fileURL];

    pthread_mutex_init(&_mutex, NULL);
    return self;
}

#pragma mark - Reparse (incremental)

- (void)reparseFile:(NSString*)content withArgs:(NSArray*)args
{
    
    NSString *extension = [_file.fileURL pathExtension];
    
    if([extension isEqualToString:@"h"])
    {
        args = [args arrayByAddingObjectsFromArray:@[
            @"-x",
            @"objective-c-header"
        ]];
    }
    else if([extension isEqualToString:@"hpp"])
    {
        args = [args arrayByAddingObjectsFromArray:@[
            @"-x",
            @"c++-header"
        ]];
    }
    
    /* getting data from content (dont allow lossy conversion, because otherwise chineese, japanese, etc users are pissed off)*/
    NSData *newData = [content dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    if(!newData)
    {
        return;
    }
    
    pthread_mutex_lock(&_mutex);
    
    /* checking for unit */
    if(_unit == nil)
    {
        /* needs reactivation */
        pthread_mutex_unlock(&_mutex);
        [self reactivateWithData:newData withArgs:args];
        return;
    }
    
    [_file setUnsavedData:newData];
    [_unit reparse];

    pthread_mutex_unlock(&_mutex);
}

- (NSArray<LDEDiagnostic *> *)getDiagnostics
{
    pthread_mutex_lock(&_mutex);

    /* checking if unit is already active */
    if(_unit == nil)
    {
        /* its not so fall back to being an asshole */
        pthread_mutex_unlock(&_mutex);
        return @[];
    }
    
    NSArray<LDEDiagnostic *> *items = [_unit diagnostics];
    pthread_mutex_unlock(&_mutex);
    return items;
}

#pragma mark - Memory management

- (void)releaseMemory
{
    pthread_mutex_lock(&_mutex);
    _unit = nil;
    pthread_mutex_unlock(&_mutex);
}

- (BOOL)isActive
{
    pthread_mutex_lock(&_mutex);
    BOOL active = (_unit != nil);
    pthread_mutex_unlock(&_mutex);
    return active;
}

- (BOOL)reactivateWithData:(NSData*)data withArgs:(NSArray*)args
{
    /* checking if server is still active */
    if([self isActive])
    {
        return YES;
    }
    
    /* its not so we need to reactivate it */
    pthread_mutex_lock(&_mutex);
    
    /* creating new synpush core and update all */
    _unit = [LDEMutableASTUnit unit];
    if(_unit == nil)
    {
        pthread_mutex_unlock(&_mutex);
        return false;
    }
    
    [_unit setFile:_file];
    [_unit setArguments:args];
    bool succeed = [_unit reparse];
    
    pthread_mutex_unlock(&_mutex);
    
    return succeed;
}

- (void)dealloc
{
    /* destroying the lock */
    pthread_mutex_destroy(&_mutex);
}

- (Syndef*)getDefinitionAtLine:(unsigned)line
                        column:(unsigned)column
{
    return nil;
}

@end
