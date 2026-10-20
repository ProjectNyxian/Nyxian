/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2025 - 2026 emexlab

 This file is part of Nyxian.

 Licensed under the emexLabs Public Source License, version 1.1
 (EPSL 1.1).

 Private use and modification are permitted under the license.
 Redistribution of source or binaries, modified or unmodified,
 requires prior written permission from emexLabs.

 External deployment is subject to the source-availability
 requirements and other conditions of the license.

 Provided "AS IS", without warranty, to the extent permitted by law.

 See LICENSE for the full license terms.
*/

#import <LindChain/IDELanguageServer/NXLanguageServer.h>
#import <MobileDevelopmentKit/MDKASTUnit.h>
#import <MobileDevelopmentKit/MDKFile.h>
#import <string.h>
#import <strings.h>
#include <os/lock.h>

#pragma mark - SynpushServer

@implementation NXLanguageServer {
    os_unfair_lock _lock;
    MDKMutableASTUnit *_unit;
    MDKMutableFile *_file;
}

- (instancetype)init:(NSString*)filepath
{
    self = [super init];
    if(!self) return nil;
    
    /* initializing step numero uno */
    NSURL *fileURL = [NSURL fileURLWithPath:filepath];
    _file = [MDKMutableFile fileWithURL:fileURL];
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

- (NSArray<MDKDiagnostic *> *)getDiagnostics
{
    os_unfair_lock_lock(&_lock);

    /* checking if unit is already active */
    if(_unit == nil)
    {
        /* its not so fall back to being an asshole */
        os_unfair_lock_unlock(&_lock);
        return @[];
    }
    
    NSArray<MDKDiagnostic *> *items = [_unit diagnostics];
    os_unfair_lock_unlock(&_lock);
    
    NSMutableArray<MDKDiagnostic *> *filteredItems = [NSMutableArray array];
    for(MDKDiagnostic *diagnostic in items)
    {
        if([diagnostic.fileSourceLocation.fileURL isEqual:_file.fileURL])
        {
            NSLog(@"%@", diagnostic.message);
            [filteredItems addObject:diagnostic];
        }
    }
    
    return filteredItems;
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
    _unit = [MDKMutableASTUnit unitWithType:_file.isSwift ? MDKASTUnitTypeSwift : MDKASTUnitTypeClang];
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

- (MDKFileSourceLocation*)getDefinitionAtLocation:(MDKSourceLocation)location
{
    os_unfair_lock_lock(&_lock);
    MDKFileSourceLocation *fileSourceLocation = [_unit fileSourceLocationForDefinitionAtLocation:location];
    os_unfair_lock_unlock(&_lock);
    return fileSourceLocation;
}

@end
