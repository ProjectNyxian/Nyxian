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

#ifndef PROCENVIRONMENT_FDMAPOBJECT_H
#define PROCENVIRONMENT_FDMAPOBJECT_H

/* ----------------------------------------------------------------------
 *  Apple API Headers
 * -------------------------------------------------------------------- */
#import <Foundation/Foundation.h>

/* ----------------------------------------------------------------------
 *  Environment API Headers
 * -------------------------------------------------------------------- */
#import <LindChain/ProcEnvironment/Object/PEObject.h>

/* ----------------------------------------------------------------------
 *  Class Declarations
 * -------------------------------------------------------------------- */
/*!
 @class FDMapObject
 @abstract A wrapper for managing a process's file descriptor map.
 @discussion
    FDMapObject provides an Objective-C interface for copying,
    applying, and manipulating the file descriptor table of a process.
    It is designed to be passed across XPC boundaries and supports
    NSSecureCoding for safe serialization.
 */
@interface FDMapObject : PEObject <NSSecureCoding>

/*!
 @property fd_map
 @abstract The underlying XPC object representing the file descriptor map.
 @discussion
    This property is typically managed internally by FDMapObject
    and should not be modified directly by clients.
 */
@property (nonatomic) NSObject<OS_xpc_object> *fd_map;

/*!
 @method currentMap
 @abstract Returns a instance that is referencing the current FD map of the process.
 */
+ (instancetype)currentMap;

+ (instancetype)emptyMap;

+ (instancetype)stdfdMap;

- (void)insertOutFD:(int)stdoutFD ErrFD:(int)stderrFD InPipe:(int)stdinFD;

/*!
 @method copy_fd_map
 @abstract Copies the file descriptor map of the current process.
 @discussion
    This method captures the current process’s file descriptor table
    into the receiver’s `fd_map` property. The copied state can later
    be applied to another process.
 */
- (void)copy_fd_map;

/*!
 @method apply_fd_map
 @abstract Applies the stored file descriptor map to the current process.
 @discussion
    This method overwrites the process’s current file descriptor table
    with the stored `fd_map`. Intended for initializing a new process
    with a specific descriptor layout.
 */
- (void)apply_fd_map;

/*!
 @method closeWithFileDescriptor:
 @abstract Closes a specific file descriptor.
 @param fd
    The integer file descriptor to close.
 @return
    0 on success, or -1 on failure with errno set appropriately.
 */
- (int)closeWithFileDescriptor:(int)fd;

/*!
 @method dup2WithOldFileDescriptor:withNewFileDescriptor:
 @abstract Duplicates a file descriptor to a new one, replacing it if necessary.
 @param oldFd
    The source file descriptor to duplicate.
 @param newFd
    The destination file descriptor to overwrite.
 @return
    The value of `newFd` on success, or -1 on failure with errno set appropriately.
 */
- (int)dup2WithOldFileDescriptor:(int)oldFd withNewFileDescriptor:(int)newFd;

@end

#endif /* PROCENVIRONMENT_FDMAPOBJECT_H */
