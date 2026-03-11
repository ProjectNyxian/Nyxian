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

#import <LindChain/ProcEnvironment/Object/FDMapObject.h>
#import <LindChain/LiveContainer/Tweaks/libproc.h>
#import <xpc/xpc.h>
#include <LindChain/ProcEnvironment/Utils/fd.h>

@implementation FDMapObject

- (instancetype)init
{
    self = [super init];
    if(self == nil)
    {
        return nil;
    }
    
    self.fd_map = [[NSMutableDictionary alloc] init];
    
    if(self.fd_map == nil)
    {
        return nil;
    }
    return self;
}

+ (instancetype)currentMap
{
    FDMapObject *map = [[FDMapObject alloc] init];
    
    if(map == nil)
    {
        return nil;
    }
    
    [map copy_fd_map];
    return map;
}

+ (instancetype)emptyMap
{
    FDMapObject *map = [[FDMapObject alloc] init];
    return map;
}

#pragma mark - Copying and applying file descriptor map (Unlike NSFileHandle this is used to transfer entire file descriptor maps)

- (void)copy_fd_map
{
    int numFDs = 0;
    struct proc_fdinfo *fdinfo = NULL;
    
    get_all_fds(&numFDs, &fdinfo);
    
    for(int i = 0; i < numFDs; i++)
    {
        int fd = fdinfo[i].proc_fd;
        FDObject *fdObject = [FDObject objectForFileDescriptor:fd];
        
        if(fdObject == nil)
        {
            continue;
        }
        
        [self.fd_map setObject:fdObject forKey:@(fd)];
    }

    free(fdinfo);
    return;
}

/// Intended for a brand new process, overmapping the current fd map
- (void)apply_fd_map
{
    close_all_fd();
    if(!_fd_map)
    {
        return;
    }
    
    for(NSNumber *key in _fd_map.allKeys)
    {
        if(key == nil)
        {
            continue;
        }
        
        FDObject *fdObject = _fd_map[key];
        
        if(fdObject != nil)
        {
            [fdObject dup2:[key intValue]];
        }
    }
}

#pragma mark - Handling file descriptors without affecting host (Used by fork() and posix_spawn() fix for example)

- (int)appendFileDescriptor:(int)fd withMappingToLoc:(int)loc
{
    if(!_fd_map)
    {
        errno = EINVAL;
        return -1;
    }
    
    FDObject *object = [FDObject objectForFileDescriptor:fd];
    
    if(object == nil)
    {
        errno = EBADF;
        return -1;
    }
    
    [_fd_map setObject:object forKey:@(loc)];
    
    return 0;
}

- (int)appendFileDescriptor:(int)fd
{
    return [self appendFileDescriptor:fd withMappingToLoc:fd];
}

- (int)closeWithFileDescriptor:(int)fd
{
    if(!_fd_map)
    {
        errno = EINVAL;
        return -1;
    }
    
    [_fd_map removeObjectForKey:@(fd)];
    
    return 0;
}

- (int)dup2WithOldFileDescriptor:(int)oldFd withNewFileDescriptor:(int)newFd
{
    if (!_fd_map) return -1;

    /* find object in reference to oldFD */
    FDObject *fdObject = [_fd_map objectForKey:@(oldFd)];
    
    if(fdObject == nil)
    {
        errno = EBADF;
        return -1;
    }
    
    /* remove from old location */
    [_fd_map removeObjectForKey:@(oldFd)];
    
    /* re-add at new location */
    [_fd_map setObject:fdObject forKey:@(newFd)];
    
    return 0;
}

#pragma mark - Transmission

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder
{
    [coder encodeObject:[_fd_map copy] forKey:@"fd_map"];
    return;
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    self = [super init];
    NSDictionary *dictionary = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSDictionary class], [NSNumber class], [FDObject class], nil] forKey:@"fd_map"];
    if(dictionary != nil)
    {
        _fd_map = [dictionary mutableCopy];
    }
    return self;
}

@end
