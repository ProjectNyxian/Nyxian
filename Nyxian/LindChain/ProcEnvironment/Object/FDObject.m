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

#import <LindChain/ProcEnvironment/Object/FDObject.h>
#include <fcntl.h>

@implementation FDObject

- (instancetype)init
{
    self = [super init];
    return self;
}

+ (instancetype)objectForFileDescriptor:(int)fd
{
    FDObject *object = [[self alloc] init];
    if(object != nil)
    {
        object.fd = xpc_fd_create(fd);
    }
    return object;
}

+ (instancetype)objectForFileAtPath:(NSString*)path
                          withFlags:(int)flags
                    withPermissions:(int)perm
{
    int fd = open([path UTF8String], flags, perm);
    
    if(fd < 0)
    {
        return nil;
    }
    
    return [self objectForFileDescriptor:fd];
}

+ (instancetype)objectForFileAtPath:(NSString*)path
                          withFlags:(int)flags
{
    return [self objectForFileAtPath:path withFlags:flags withPermissions:0777];
}

+ (instancetype)objectForFileAtPath:(NSString*)path
{
    return [self objectForFileAtPath:path withFlags:O_RDWR];
}

- (void)setFileDescriptor:(int)fd
{
    _fd = xpc_fd_create(fd);
}

- (void)dup2:(int)fd
{
    int cfd = xpc_fd_dup(_fd);
    if(cfd == fd)
    {
        return;
    }
    else
    {
        dup2(cfd, fd);
        close(cfd);
    }
}

- (BOOL)writeOut:(NSString*)path
{
    /* open temporary file descriptor */
    int tmpfd = xpc_fd_dup(_fd);
    
    if(tmpfd < 0)
    {
        return NO;
    }
    
    /* get current position to be restored later */
    off_t cur = lseek(tmpfd, 0, SEEK_CUR);
    
    /* reset temporary file descriptor to the beginning of the file */
    if(lseek(tmpfd, 0, SEEK_SET) == -1)
    {
        lseek(tmpfd, cur, SEEK_SET);
        close(tmpfd);
        return NO;
    }
    
    /* create or truncate the destination file */
    int dstFd = open([path UTF8String], O_WRONLY | O_CREAT | O_TRUNC, 0777);
    if(dstFd == -1)
    {
        lseek(tmpfd, cur, SEEK_SET);
        close(tmpfd);
        return NO;
    }
    
    char buffer[16384];
    ssize_t bytesRead;
    off_t offset = 0;
    
    /* writing file out to dstfd */
    while((bytesRead = read(tmpfd, buffer, sizeof(buffer))) > 0)
    {
        ssize_t bytesWritten = 0;
        while(bytesWritten < bytesRead)
        {
            ssize_t w = write(dstFd, buffer + bytesWritten, bytesRead - bytesWritten);
            if(w == -1)
            {
                lseek(tmpfd, cur, SEEK_SET);
                close(tmpfd);
                close(dstFd);
                return NO;
            }
            bytesWritten += w;
        }
        offset += bytesRead;
    }
    
    /* closing and resetting tmp because we dont need it anymore anyways */
    lseek(tmpfd, cur, SEEK_SET);
    close(tmpfd);
    
    if(bytesRead == -1)
    {
        close(dstFd);
        return NO;
    }
    
    if(close(dstFd) == -1)
    {
        return NO;
    }
    
    return YES;
}

- (BOOL)writeIn:(NSString*)path
{
    /* open temporary file descriptor */
    int tmpfd = xpc_fd_dup(_fd);
    
    if(tmpfd < 0)
    {
        return NO;
    }
    
    /* get current position to be restored later */
    off_t cur = lseek(tmpfd, 0, SEEK_CUR);
    
    /* reset temporary file descriptor to the beginning of the file */
    if(lseek(tmpfd, 0, SEEK_SET) == -1)
    {
        lseek(tmpfd, cur, SEEK_SET);
        close(tmpfd);
        return NO;
    }
    
    /* open source file */
    int srcFd = open([path UTF8String], O_RDONLY);
    if(srcFd == -1)
    {
        lseek(tmpfd, cur, SEEK_SET);
        close(tmpfd);
        return NO;
    }

    char buffer[16384];
    ssize_t bytesRead;

    if(lseek(tmpfd, 0, SEEK_SET) == -1)
    {
        close(srcFd);
        lseek(tmpfd, cur, SEEK_SET);
        close(tmpfd);
        return NO;
    }

    if(ftruncate(tmpfd, 0) == -1)
    {
        close(srcFd);
        lseek(tmpfd, cur, SEEK_SET);
        close(tmpfd);
        return NO;
    }

    while((bytesRead = read(srcFd, buffer, sizeof(buffer))) > 0)
    {
        ssize_t bytesWritten = 0;
        while(bytesWritten < bytesRead)
        {
            ssize_t w = write(tmpfd, buffer + bytesWritten, bytesRead - bytesWritten);
            if(w == -1)
            {
                lseek(tmpfd, cur, SEEK_SET);
                close(tmpfd);
                close(srcFd);
                return NO;
            }
            bytesWritten += w;
        }
    }

    if(bytesRead == -1)
    {
        lseek(tmpfd, cur, SEEK_SET);
        close(tmpfd);
        close(srcFd);
        return NO;
    }

    if(close(srcFd) == -1)
    {
        lseek(tmpfd, cur, SEEK_SET);
        close(tmpfd);
        return NO;
    }
    
    return YES;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder
{
    if([coder respondsToSelector:@selector(encodeXPCObject:forKey:)])
    {
        [(id)coder encodeXPCObject:_fd forKey:@"fd"];
    }
    
    return;
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    self = [super init];
    if([coder respondsToSelector:@selector(decodeXPCObjectOfType:forKey:)])
    {
        _fd = [(id)coder decodeXPCObjectOfType:XPC_TYPE_FD forKey:@"fd"];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    FDObject *copy = [[[self class] allocWithZone:zone] init];
    copy.fd = [self.fd copy];
    return copy;
}

+ (BOOL)forceVnodeReassignment:(NSString*)path
{
    if(path == nil)
    {
        return NO;
    }
    
    NSFileManager *fm = [NSFileManager defaultManager];

    NSString *uuid = [[NSUUID UUID] UUIDString];
    NSString *tmpPath = [[path stringByDeletingLastPathComponent] stringByAppendingPathComponent:uuid];
    
    if(tmpPath == nil)
    {
        return NO;
    }

    /* ->copy<- to temporary directory */
    NSError *error = nil;
    if(![fm copyItemAtPath:path toPath:tmpPath error:&error])
    {
        return NO;
    }
    
    /* unlinking original */
    if(unlink(path.fileSystemRepresentation) != 0)
    {
        [fm removeItemAtPath:tmpPath error:nil];
        return NO;
    }

    /* move copy back to original location */
    if(![fm moveItemAtPath:tmpPath toPath:path error:&error])
    {
        return NO;
    }

    return YES;
}

@end
