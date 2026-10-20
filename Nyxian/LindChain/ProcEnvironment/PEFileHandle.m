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

#import <LindChain/ProcEnvironment/PEFileHandle.h>
#include <LindChain/ProcEnvironment/Utils/fd.h>
#include <LindChain/ProcEnvironment/Utils/vnode.h>
#include <copyfile.h>
#include <fcntl.h>
#include <unistd.h>

static xpc_object_t pe_xpc_fd_create_snapshot(int fd)
{
    if(fd < 0)
    {
        return NULL;
    }
    
    int own = fcntl(fd, F_DUPFD_CLOEXEC, 0);
    if(own < 0)
    {
        return NULL;
    }
    
    xpc_object_t x = xpc_fd_create(own);
    int saved = errno;
    close(own);
    errno = (x == NULL) ? (saved ? saved : EBADF) : saved;
    return x;
}

@implementation PEFileHandle

- (instancetype)init
{
    self = [super init];
    return self;
}

+ (instancetype)handleForFileDescriptor:(int)fd
{
    if(fd < 0 || fd_is_guarded(fd))
    {
        errno = EBADF;
        return nil;
    }
    
    xpc_object_t x = pe_xpc_fd_create_snapshot(fd);
    if(x == NULL)
    {
        return nil;
    }
    
    PEFileHandle *object = [[self alloc] init];
    if(object != nil)
    {
        object.fd = x;
    }
    
    return object;
}

+ (instancetype)handleForFilePort:(fileport_t)fp
{
    int fd = fileport_makefd(fp);
    if(fd < 0)
    {
        return nil;
    }
    
    PEFileHandle *object = [self handleForFileDescriptor:fd];
    close(fd);
    return object;
}

+ (instancetype)handleForFileAtPath:(NSString*)path
                          withFlags:(int)flags
                    withPermissions:(int)perm
{
    if(path == nil)
    {
        errno = EINVAL;
        return nil;
    }
    
    int fd = open([path fileSystemRepresentation], flags | O_CLOEXEC, perm);
    if(fd < 0)
    {
        return nil;
    }
    
    PEFileHandle *object = [self handleForFileDescriptor:fd];
    close(fd);
    return object;
}

+ (instancetype)handleForFileAtPath:(NSString*)path
                          withFlags:(int)flags
{
    return [self handleForFileAtPath:path withFlags:flags withPermissions:0777];
}

+ (instancetype)handleForFileAtPath:(NSString*)path
{
    return [self handleForFileAtPath:path withFlags:O_RDWR];
}

- (void)setFileDescriptor:(int)fd
{
    xpc_object_t x = pe_xpc_fd_create_snapshot(fd);
    if(x != NULL)
    {
        _fd = x;
    }
}

- (int)extractFileDescriptor
{
    if(_fd == nil)
    {
        errno = EBADF;
        return -1;
    }
    return xpc_fd_dup(_fd);
}

- (BOOL)extractFileDescriptorToLoc:(int)loc
{
    if(loc < 0 || fd_is_guarded(loc))
    {
        return NO;
    }
    
    int cfd = [self extractFileDescriptor];
    if(cfd < 0)
    {
        return NO;
    }
    
    if(cfd == loc)
    {
        int flags = fcntl(cfd, F_GETFD);
        if(flags >= 0 && (flags & FD_CLOEXEC))
        {
            fcntl(cfd, F_SETFD, flags & ~FD_CLOEXEC);
        }
        return YES;
    }
    
    int retval = dup2(cfd, loc);
    close(cfd);
    return retval >= 0;
}

- (BOOL)writeOut:(NSString*)path
{
    int tmpfd = [self extractFileDescriptor];
    if(tmpfd < 0)
    {
        return NO;
    }
    
    /* reset temporary file descriptor to the beginning of the file */
    if(lseek(tmpfd, 0, SEEK_SET) == -1)
    {
        close(tmpfd);
        return NO;
    }
    
    bool success = vnode_recover_with_fd_to_path(tmpfd, [path fileSystemRepresentation]);
    close(tmpfd);
    return success ? YES : NO;
}

- (BOOL)writeIn:(NSString*)path
{
    int tmpfd = [self extractFileDescriptor];
    if(tmpfd < 0)
    {
        return NO;
    }
    
    int srcFd = open([path fileSystemRepresentation], O_RDONLY | O_CLOEXEC);
    if(srcFd < 0)
    {
        close(tmpfd);
        return NO;
    }
    
    if(ftruncate(tmpfd, 0) != 0 || lseek(tmpfd, 0, SEEK_SET) == -1)
    {
        close(srcFd);
        close(tmpfd);
        return NO;
    }
    
    int ret = fcopyfile(srcFd, tmpfd, NULL, COPYFILE_DATA);
    
    close(srcFd);
    close(tmpfd);
    
    return ret == 0;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder
{
    if(_fd != nil)
    {
        [(id)coder encodeXPCObject:_fd forKey:@"fd"];
    }
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    self = [super init];
    if(self)
    {
        _fd = [(id)coder decodeXPCObjectOfType:XPC_TYPE_FD forKey:@"fd"];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    PEFileHandle *copy = [[[self class] allocWithZone:zone] init];
    copy.fd = self.fd;
    return copy;
}

@end
