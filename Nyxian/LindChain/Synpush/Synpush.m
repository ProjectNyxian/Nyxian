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
#import <pthread.h>
#import <string.h>
#import <strings.h>


#pragma mark - SynpushServer

@interface SynpushServer () {
    NSData *_contentData;
    NSString *_filepath;
    char *_cFilename;
    int _argc;
    char **_args;
    pthread_mutex_t _mutex;
    
    spcore_t _spc;
}
@end

@implementation SynpushServer

- (instancetype)init:(NSString*)filepath
{
    self = [super init];
    if(!self) return nil;
    
    /* initilizing step numero uno */
    _filepath = [filepath copy];
    _cFilename = strdup(_filepath.UTF8String);

    pthread_mutex_init(&_mutex, NULL);
    return self;
}

#pragma mark - Reparse (incremental)

- (void)reparseFile:(NSString*)content withArgs:(NSArray*)args
{
    NSString *extension = [_filepath pathExtension];
    
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
    if(!_spc)
    {
        /* needs reactivation */
        pthread_mutex_unlock(&_mutex);
        [self reactivateWithData:newData withArgs:args];
        return;
    }
    
    _contentData = newData;
    
    SPUpdateFileContent(_spc, _cFilename, _contentData.bytes, _contentData.length);
    SPCreateUnit(_spc);

    pthread_mutex_unlock(&_mutex);
}

- (NSArray<Syndiag *> *)getDiagnostics
{
    pthread_mutex_lock(&_mutex);

    /* checking if unit is already active */
    if(_spc == NULL)
    {
        /* its not so fall back to being an asshole */
        pthread_mutex_unlock(&_mutex);
        return @[];
    }
    
    uint64_t count = SPDiagnosticCount(_spc);
    
    /* preallocating array with count of items */
    NSMutableArray<Syndiag *> *items = [NSMutableArray arrayWithCapacity:count];

    //CXFile targetFile = NULL;
    for(uint64_t i = 0; i < count; ++i)
    {
        /* getting diagnostic */
        spdiag_t diag = SPDiagnosticGet(_spc, i);
        
        /* TODO: remove this check, let the Coordinator do this */
        if(diag.type == SPDiagTypeTargetFile)
        {
            /* creating actual SynItem! */
            Syndiag *item = [[Syndiag alloc] init];
            item.line = diag.line;
            item.column = diag.column;
            item.type = diag.type;
            item.level = diag.level;
            item.message = [NSString stringWithCString:diag.message encoding:NSUTF8StringEncoding];
            [items addObject:item];
        }
        
        SPDiagnosticDestroy(diag);
    }

    pthread_mutex_unlock(&_mutex);
    return items;
}

#pragma mark - Memory management

- (void)releaseMemory
{
    pthread_mutex_lock(&_mutex);
    
    /* dispose many clang things to get rid of most */
    if(_spc != NULL)
    {
        SPFreeCore(_spc);
    }
    
    /* releasing content data memory */
    _contentData = [@"" dataUsingEncoding:NSUTF8StringEncoding];
    
    pthread_mutex_unlock(&_mutex);
}

- (BOOL)isActive
{
    pthread_mutex_lock(&_mutex);
    BOOL active = (_spc != NULL);
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
    
    /* free if allocated */
    if(_args != NULL)
    {
        for (int i = 0; i < _argc; ++i) free(_args[i]);
        free(_args);
    }
    
    /* making arguments ready */
    _argc = (int)args.count;
    _args = (char**)calloc((size_t)_argc, sizeof(char*));
    for(int i = 0; i < _argc; ++i)
    {
        _args[i] = strdup([args[i] UTF8String]);
    }
    
    /* making sure that bytes doesnt get deallocated randomly */
    _contentData = data;
    
    /* creating new synpush core and update all */
    _spc = SPCreateCore(_argc, (const char**)_args);
    SPUpdateFileContent(_spc, _cFilename, _contentData.bytes, _contentData.length);
    bool succeed = SPCreateUnit(_spc);
    
    pthread_mutex_unlock(&_mutex);
    
    return succeed;
}

- (void)dealloc
{
    /* locking and disposing lol */
    pthread_mutex_lock(&_mutex);
    if(_spc != NULL)
    {
        SPFreeCore(_spc);
    }
    
    if(_args != NULL)
    {
        
        /* releasing da rest */
        for (int i = 0; i < _argc; ++i) free(_args[i]);
        free(_args);
    }
    
    pthread_mutex_unlock(&_mutex);
    
    free(_cFilename);
    
    /* destroying the lock */
    pthread_mutex_destroy(&_mutex);
}

- (Syndef*)getDefinitionAtLine:(unsigned)line
                        column:(unsigned)column
{
    return nil;
}

@end

