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

#import <LindChain/ProcEnvironment/Object/FDMapObject.h>
#import <LindChain/LiveContainer/Tweaks/libproc.h>
#import <xpc/xpc.h>
#include <LindChain/ProcEnvironment/Utils/fd.h>

@implementation FDMapObject

+ (instancetype)currentMap
{
    FDMapObject *map = [[FDMapObject alloc] init];
    [map copy_fd_map];
    return map;
}

+ (instancetype)emptyMap
{
    FDMapObject *map = [[FDMapObject alloc] init];
    return map;
}

+ (instancetype)stdfdMap
{
    FDMapObject *map = [self emptyMap];
    map.fd_map = xpc_array_create_empty();
    
    // Stdout
    xpc_object_t dict = xpc_dictionary_create_empty();
    xpc_dictionary_set_fd(dict, "actual_fd", STDOUT_FILENO);
    xpc_dictionary_set_int64(dict, "wished_fd", STDOUT_FILENO);
    xpc_array_append_value(map.fd_map, dict);
    
    // Stderr
    dict = xpc_dictionary_create_empty();
    xpc_dictionary_set_fd(dict, "actual_fd", STDERR_FILENO);
    xpc_dictionary_set_int64(dict, "wished_fd", STDERR_FILENO);
    xpc_array_append_value(map.fd_map, dict);
    
    // Stdin
    dict = xpc_dictionary_create_empty();
    xpc_dictionary_set_fd(dict, "actual_fd", STDIN_FILENO);
    xpc_dictionary_set_int64(dict, "wished_fd", STDIN_FILENO);
    xpc_array_append_value(map.fd_map, dict);
    
    return map;
}

#pragma mark - Copying and applying file descriptor map (Unlike NSFileHandle this is used to transfer entire file descriptor maps)

- (void)insertStdPipe:(int*)stdoutPipe
           StdErrPipe:(int*)stderrPipe
            StdInPipe:(int*)stdinPipe
{
    _fd_map = xpc_array_create_empty();
    
    // Stdout
    xpc_object_t dict = xpc_dictionary_create_empty();
    xpc_dictionary_set_fd(dict, "actual_fd", stdoutPipe[1]);
    xpc_dictionary_set_int64(dict, "wished_fd", STDOUT_FILENO);
    xpc_array_append_value(_fd_map, dict);
    
    // Stderr
    dict = xpc_dictionary_create_empty();
    xpc_dictionary_set_fd(dict, "actual_fd", stderrPipe[1]);
    xpc_dictionary_set_int64(dict, "wished_fd", STDERR_FILENO);
    xpc_array_append_value(_fd_map, dict);
    
    // Stdin
    dict = xpc_dictionary_create_empty();
    xpc_dictionary_set_fd(dict, "actual_fd", stdinPipe[0]);
    xpc_dictionary_set_int64(dict, "wished_fd", STDIN_FILENO);
    xpc_array_append_value(_fd_map, dict);
}

- (void)copy_fd_map
{
    _fd_map = xpc_array_create_empty();
    
    int numFDs = 0;
    struct proc_fdinfo *fdinfo = NULL;
    
    get_all_fds(&numFDs, &fdinfo);

    for (int i = 0; i < numFDs; i++) {
        int fd = fdinfo[i].proc_fd;
        @try {
            xpc_object_t dict = xpc_dictionary_create_empty();
            xpc_dictionary_set_fd(dict, "actual_fd", fd);
            xpc_dictionary_set_int64(dict, "wished_fd", fd);
            xpc_array_append_value(_fd_map, dict);
        } @catch (__unused NSException *ex) {
            continue;
        }
    }

    free(fdinfo);
    return;
}

/// Intended for a brand new process, overmapping the fd map
- (void)apply_fd_map
{
    close_all_fd();
    if (!_fd_map) return;
    xpc_array_apply(_fd_map, ^bool(size_t index, xpc_object_t entry){
        int wished_fd   = (int)xpc_dictionary_get_int64(entry, "wished_fd");
        int incoming_fd = xpc_dictionary_dup_fd(entry, "actual_fd");

        if (incoming_fd >= 0)
        {
            if (dup2(incoming_fd, wished_fd) < 0)
            {
                perror("dup2");
            }
            if (incoming_fd != wished_fd)
            {
                close(incoming_fd);
            }
        }

        return true;
    });
}

#pragma mark - Handling file descriptors without affecting host (Used by fork() and posix_spawn() fix for example)

// TODO: Only handle them as xpc dictionaries on encoding and decoding (will save power and time later on)
- (int)closeWithFileDescriptor:(int)fd
{
    if (!_fd_map) return -1;
    
    __block int ret = -1;
    
    NSObject<OS_xpc_object> *new_fd_map = xpc_array_create_empty();
    
    xpc_array_apply(_fd_map, ^bool(size_t index, xpc_object_t entry){
        int wished_fd   = (int)xpc_dictionary_get_int64(entry, "wished_fd");
        if(wished_fd != fd)
        {
            xpc_array_append_value(new_fd_map, entry);
        }
        else
        {
            // Hit it! so it was in it!
            ret = 0;
        }
        return true;
    });
    
    _fd_map = new_fd_map;
    
    return ret;
}

- (int)dup2WithOldFileDescriptor:(int)oldFd withNewFileDescriptor:(int)newFd
{
    if (!_fd_map) return -1;

    __block int ret = -1;
    xpc_object_t new_fd_map = xpc_array_create(NULL, 0);

    // MARK: Main logic for replacements
    xpc_array_apply(_fd_map, ^bool(size_t index, xpc_object_t entry) {
        int wished_fd = (int)xpc_dictionary_get_int64(entry, "wished_fd");

        if(wished_fd == newFd)
        {
            xpc_object_t dict = xpc_dictionary_create(NULL, NULL, 0);
            xpc_dictionary_set_fd(dict, "actual_fd", oldFd);
            xpc_dictionary_set_int64(dict, "wished_fd", newFd);
            xpc_array_append_value(new_fd_map, dict);
            ret = newFd;
        }
        else
        {
            xpc_array_append_value(new_fd_map, entry);
        }
        return true;
    });

    // MARK: Sub logic in case it was never in it, because they we have to add it
    if(ret == -1)
    {
        xpc_object_t dict = xpc_dictionary_create(NULL, NULL, 0);
        xpc_dictionary_set_fd(dict, "actual_fd", oldFd);
        xpc_dictionary_set_int64(dict, "wished_fd", newFd);
        xpc_array_append_value(new_fd_map, dict);
        ret = newFd;
    }

    _fd_map = new_fd_map;
    return ret;
}

#pragma mark - Transmission

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder
{
    if([coder respondsToSelector:@selector(encodeXPCObject:forKey:)])
    {
        [(id)coder encodeXPCObject:_fd_map forKey:@"fd_map"];
    }
    
    return;
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    self = [super init];
    if([coder respondsToSelector:@selector(decodeXPCObjectOfType:forKey:)])
    {
        struct _xpc_type_s *arrayType = (struct _xpc_type_s *)XPC_TYPE_ARRAY;
        NSObject<OS_xpc_object> *obj = [(id)coder decodeXPCObjectOfType:arrayType
                                                                 forKey:@"fd_map"];
        if(obj) _fd_map = obj;
    }
    return self;
}

@end
