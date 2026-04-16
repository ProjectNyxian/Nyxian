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
#import <string.h>
#import <strings.h>
#include <os/lock.h>

#pragma mark - SynpushServer

@interface SynpushServer () {
    os_unfair_lock _lock;
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
    _file = [LDEMutableFile fileWithURL:fileURL];
    _lock = OS_UNFAIR_LOCK_INIT;
    return self;
}

#pragma mark - Reparse (incremental)

- (void)reparseFile:(NSString*)content withArgs:(NSArray*)args
{
    /* getting data from content (dont allow lossy conversion, because otherwise chineese, japanese, etc users are pissed off)*/
    NSData *newData = [content dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:NO];
    if(!newData)
    {
        return;
    }
    
    os_unfair_lock_lock(&_lock);
    
    /* checking for unit */
    if(_unit == nil)
    {
        /* needs reactivation */
        os_unfair_lock_unlock(&_lock);
        [self reactivateWithData:newData withArgs:args];
        return;
    }
    
    [_file setUnsavedData:newData];
    [_unit reparse];

    os_unfair_lock_unlock(&_lock);
}

- (NSArray<LDEDiagnostic *> *)getDiagnostics
{
    os_unfair_lock_lock(&_lock);

    /* checking if unit is already active */
    if(_unit == nil)
    {
        /* its not so fall back to being an asshole */
        os_unfair_lock_unlock(&_lock);
        return @[];
    }
    
    NSArray<LDEDiagnostic *> *items = [_unit diagnostics];
    os_unfair_lock_unlock(&_lock);
    return items;
}

#pragma mark - Memory management

- (void)releaseMemory
{
    os_unfair_lock_lock(&_lock);
    _unit = nil;
    os_unfair_lock_unlock(&_lock);
}

- (BOOL)isActive
{
    os_unfair_lock_lock(&_lock);
    BOOL active = (_unit != nil);
    os_unfair_lock_unlock(&_lock);
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
    os_unfair_lock_lock(&_lock);
    
    /* creating new synpush core and update all */
    _unit = [LDEMutableASTUnit unit];
    if(_unit == nil)
    {
        os_unfair_lock_unlock(&_lock);
        return false;
    }
    
    [_file setUnsavedData:data];
    [_unit setFile:_file];
    [_unit setArguments:args];
    bool succeed = [_unit reparse];
    
    os_unfair_lock_unlock(&_lock);
    
    return succeed;
}

- (LDEFileSourceLocation*)getDefinitionAtLocation:(CCSourceLocation)location
{
    os_unfair_lock_lock(&_lock);
    LDEFileSourceLocation *fileSourceLocation = [_unit fileSourceLocationForDefinitionAtLocation:location];
    os_unfair_lock_unlock(&_lock);
    return fileSourceLocation;
}

@end
