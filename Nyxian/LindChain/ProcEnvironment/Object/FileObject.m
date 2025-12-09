/*
 Copyright (C) 2025 cr4zyengineer

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#import <LindChain/ProcEnvironment/Object/FileObject.h>
#include <unistd.h>
#include <sys/stat.h>
#include <copyfile.h>

@implementation FileObject

- (instancetype)initWithPath:(NSString*)path
                   withFlags:(UInt32)flags
{
    self = [super init];
    _path = path;
    _fd = open([path UTF8String], flags);
    return (_fd == -1) ? nil : self;
}

- (instancetype)initWithPath:(NSString*)path
{
    return [self initWithPath:path withFlags:O_RDWR];
}

- (instancetype)initWithFileDescriptor:(int)fd
                              withPath:(NSString*)path
{
    self = [super init];
    _path = path;
    _fd = fd;
    return self;
}

- (BOOL)writeOut:(NSString *)path
{
    // Create destination (truncate if exists)
    int dstFd = open([path UTF8String], O_WRONLY | O_CREAT | O_TRUNC, 0777);
    if(dstFd == -1) return NO;

    char buffer[16384]; // 16KB buffer
    ssize_t bytesRead;
    off_t offset = 0;

    // Reset source fd to beginning
    if(lseek(_fd, 0, SEEK_SET) == -1)
    {
        close(dstFd);
        return NO;
    }

    while((bytesRead = read(_fd, buffer, sizeof(buffer))) > 0)
    {
        ssize_t bytesWritten = 0;
        while(bytesWritten < bytesRead)
        {
            ssize_t w = write(dstFd, buffer + bytesWritten, bytesRead - bytesWritten);
            if (w == -1) {
                close(dstFd);
                return NO;
            }
            bytesWritten += w;
        }
        offset += bytesRead;
    }

    if (bytesRead == -1) {
        close(dstFd);
        return NO;
    }

    if (close(dstFd) == -1) return NO;
    return YES;
}

- (BOOL)writeIn:(NSString *)path
{
    // Open source file
    int srcFd = open([path UTF8String], O_RDONLY);
    if (srcFd == -1) return NO;

    char buffer[16384];
    ssize_t bytesRead;

    if(lseek(_fd, 0, SEEK_SET) == -1)
    {
        close(srcFd);
        return NO;
    }

    if(ftruncate(_fd, 0) == -1)
    {
        close(srcFd);
        return NO;
    }

    while((bytesRead = read(srcFd, buffer, sizeof(buffer))) > 0)
    {
        ssize_t bytesWritten = 0;
        while(bytesWritten < bytesRead)
        {
            ssize_t w = write(_fd, buffer + bytesWritten, bytesRead - bytesWritten);
            if(w == -1)
            {
                close(srcFd);
                return NO;
            }
            bytesWritten += w;
        }
    }

    if(bytesRead == -1)
    {
        close(srcFd);
        return NO;
    }

    if(close(srcFd) == -1) return NO;
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
        xpc_object_t dict = xpc_dictionary_create(NULL, NULL, 0);
        xpc_dictionary_set_fd(dict, "fd", _fd);
        [(id)coder encodeXPCObject:dict forKey:@"fd"];
        [coder encodeObject:_path forKey:@"path"];
    }
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    self = [super init];
    if([coder respondsToSelector:@selector(decodeXPCObjectOfType:forKey:)])
    {
        _path = [coder decodeObjectOfClass:[NSString class] forKey:@"path"];
        struct _xpc_type_s *dictType = (struct _xpc_type_s *)XPC_TYPE_DICTIONARY;
        NSObject<OS_xpc_object> *obj = [(id)coder decodeXPCObjectOfType:dictType
                                                                 forKey:@"fd"];
        if(obj)
        {
            _fd = xpc_dictionary_dup_fd(obj, "fd");
            
            struct stat st;
            if (fstat(_fd, &st) == -1)
            {
                close(_fd);
                return nil;
            }
            if(!S_ISREG(st.st_mode))
            {
                close(_fd);
                return nil;
            }
        }
    }
    return self;
}

- (void)deinit
{
    [super deinit];
    close(_fd);
}

@end
