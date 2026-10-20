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

#ifndef PEFILETABLE_H
#define PEFILETABLE_H

/* ----------------------------------------------------------------------
 *  Apple API Headers
 * -------------------------------------------------------------------- */
#import <Foundation/Foundation.h>

/* ----------------------------------------------------------------------
 *  Environment API Headers
 * -------------------------------------------------------------------- */
#import <LindChain/ProcEnvironment/PEFileHandle.h>

/* ----------------------------------------------------------------------
 *  Class Declarations
 * -------------------------------------------------------------------- */

/*!
 @class `PEFileTable`
 @abstract Manages file descriptor mappings for process initilization.
 @discussion
    `PEFileTable` provides an Objective-C interface for copying,
    applying, and manipulating the file descriptor table of a process.
    It is designed to be passed across XPC boundaries and supports
    `NSSecureCoding` for safe serialization.
 */
@interface PEFileTable : NSObject <NSSecureCoding>

/*!
 @property `fd_map`
 @abstract The underlying NS object representing the file descriptor map.
 @discussion
    This property is typically managed internally by `PEFileTable`
    and should not be modified directly by clients.
 */
@property (nonatomic) NSMutableDictionary<NSNumber*,PEFileHandle*> *fd_map;

/*!
 @method `currentTable`
 @abstract Returns a instance that is referencing the current file descriptor table of the process.
 */
+ (instancetype)currentTable;

/*!
 @method `emptyTable`
 @abstract Returns a instance of a empty file descriptor table.
 */
+ (instancetype)emptyTable;

/*!
 @method `apply`
 @abstract Applies the stored file descriptor map to the current process.
 @discussion
    This method overwrites the process’s current file descriptor table
    with the stored `fd_map`. Intended for initializing a new process
    with a specific descriptor layout.
 */
- (void)apply;

/*!
 @method `appendFileDescriptor:withMappingToLoc:`
 @abstract Adds file descriptor to file descriptor map object.
 @param fd
    The integer representing the file descriptor to apend.
 @param loc
    The file descriptor it shall get applied to when calling [PEFileTable apply].
 */
- (int)appendFileDescriptor:(int)fd withMappingToLoc:(int)loc;

/*!
 @method `appendFilePort:withMappingToLoc:`
 @abstract Adds file descriptor to file descriptor map object.
 @param fp
    The integer representing the file port to apend.
 @param loc
    The file descriptor it shall get applied to when calling [PEFileTable apply].
 */
- (int)appendFilePort:(fileport_t)fp withMappingToLoc:(int)loc;

/*!
 @method `appendFileDescriptor:`
 @abstract Adds file descriptor to file descriptor map object.
 @param fd
    The integer representing the file descriptor to apend.
 */
- (int)appendFileDescriptor:(int)fd;

/*!
 @method `closeWithFileDescriptor:`
 @abstract Closes a specific file descriptor.
 @param fd
    The integer file descriptor to close.
 @return
    0 on success, or -1 on failure with errno set appropriately.
 */
- (int)closeWithFileDescriptor:(int)fd;

- (int)openWithFileDescriptor:(int)fd withPath:(const char*)path withFlags:(int)flags withMode:(mode_t)mode;

/*!
 @method `dup2WithOldFileDescriptor:withNewFileDescriptor:`
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

#endif /* PEFILETABLE_H */
