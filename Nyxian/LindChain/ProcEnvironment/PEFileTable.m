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

#import <LindChain/ProcEnvironment/PEFileTable.h>
#import <LindChain/ProcEnvironment/Surface/libkern/bsd/proc_info.h>
#import <xpc/xpc.h>
#include <LindChain/ProcEnvironment/Utils/fd.h>

@implementation PEFileTable

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

+ (instancetype)currentTable
{
    PEFileTable *table = [[self alloc] init];
    if(table == nil)
    {
        return nil;
    }
    
    [table copy_fd_map];
    return table;
}

+ (instancetype)emptyTable
{
    return [[self alloc] init];
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
        PEFileHandle *fileHandle = [PEFileHandle handleForFileDescriptor:fd];
        if(fileHandle == nil)
        {
            continue;
        }
        
        [self.fd_map setObject:fileHandle forKey:@(fd)];
    }

    free(fdinfo);
    return;
}

/// Intended for a brand new process, overmapping the current fd map
- (void)apply
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
        
        PEFileHandle *fileHandle = _fd_map[key];
        if(fileHandle != nil)
        {
            [fileHandle extractFileDescriptorToLoc:[key intValue]];
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
    
    PEFileHandle *object = [PEFileHandle handleForFileDescriptor:fd];
    if(object == nil)
    {
        errno = EBADF;
        return -1;
    }
    
    [_fd_map setObject:object forKey:@(loc)];
    
    return 0;
}

- (int)appendFilePort:(fileport_t)fp
     withMappingToLoc:(int)loc
{
    if(!_fd_map)
    {
        errno = EINVAL;
        return -1;
    }
    
    PEFileHandle *object = [PEFileHandle handleForFileDescriptor:fp];
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

- (int)openWithFileDescriptor:(int)fd
                     withPath:(const char*)path
                    withFlags:(int)flags
                     withMode:(mode_t)mode
{
    if(!_fd_map)
    {
        errno = EINVAL;
        return -1;
    }
    
    int hostFd = open(path, flags, mode);
    
    if(hostFd < 0)
    {
        return -1;
    }
    
    int retval = [self appendFileDescriptor:hostFd withMappingToLoc:fd];
    
    close(hostFd);
    
    return retval;
}

- (int)dup2WithOldFileDescriptor:(int)oldFd withNewFileDescriptor:(int)newFd
{
    if (!_fd_map) return -1;

    /* find object in reference to oldFD */
    PEFileHandle *fileHandle = [_fd_map objectForKey:@(oldFd)];
    if(fileHandle == nil)
    {
        errno = EBADF;
        return -1;
    }
    
    /* re-add at new location */
    [_fd_map setObject:fileHandle forKey:@(newFd)];
    
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
    NSDictionary *dictionary = [coder decodeObjectOfClasses:[NSSet setWithObjects:[NSDictionary class], [NSNumber class], [PEFileHandle class], nil] forKey:@"fd_map"];
    if(dictionary != nil)
    {
        _fd_map = [dictionary mutableCopy];
    }
    return self;
}

@end
