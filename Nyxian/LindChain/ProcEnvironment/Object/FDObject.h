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

#ifndef PROCENVIRONMENT_FDOBJECT_H
#define PROCENVIRONMENT_FDOBJECT_H

/* ----------------------------------------------------------------------
 *  Apple API Headers
 * -------------------------------------------------------------------- */
#import <Foundation/Foundation.h>
#import <LindChain/Private/mach/fileport.h>

/* ----------------------------------------------------------------------
 *  Environment API Headers
 * -------------------------------------------------------------------- */
#import <LindChain/ProcEnvironment/Object/PEObject.h>

/* ----------------------------------------------------------------------
 *  Class Declarations
 * -------------------------------------------------------------------- */

/*!
 @class `FDObject`
 @abstract Manages a single file descriptor.
 @discussion
    `FDObject` provides an Objective-C interface for copying,
    applying, and manipulating the file descriptor of a process.
    It is designed to be passed across XPC boundaries and supports
    `NSSecureCoding` for safe serialization.
 */
@interface FDObject : PEObject <NSCopying>

/*!
 @property `fd`
 @abstract The underlying XPC object representing the file descriptor.
 @discussion
    This property is typically managed internally by `FDObject`
    and should not be modified directly by clients.
 */
@property (nonatomic,strong) NSObject<OS_xpc_object> *fd;

/*!
 @method `objectForFileDescriptor:`
 @abstract Creates a object for a file descriptor.
 @param fd
    file descriptor at wish to be converted to a FDObject.
 @return
    A instance that is referencing the current file descriptor passed.
 */
+ (instancetype)objectForFileDescriptor:(int)fd;

/*!
 @method `objectForFilePort:`
 @abstract Creates a object for a file descriptor.
 @param fp
    file port at wish to be converted to a FDObject.
 @return
    A instance that is referencing the current file descriptor passed.
 */
+ (instancetype)objectForFilePort:(fileport_t)fp;

/*!
 @method `objectForFileAtPath:withFlags:withPermissions:`
 */
+ (instancetype)objectForFileAtPath:(NSString*)path withFlags:(int)flags withPermissions:(int)perm;

/*!
 @method `objectForFileAtPath:withFlags:`
 */
+ (instancetype)objectForFileAtPath:(NSString*)path withFlags:(int)flags;

/*!
 @method `objectForFileAtPath:`
 */
+ (instancetype)objectForFileAtPath:(NSString*)path;

/*!
 @method `setFileDescriptor:`
 @abstract Sets file descriptor to a other file descriptor in the object.
 @param fd
    file descriptor at wish as a replacement.
 */
- (void)setFileDescriptor:(int)fd;

/*!
 @method `dup`
 @abstract Converts the object back to a file descriptor.
 @return
    Returns file descriptor duplication is successful.
 */
- (int)dup;

/*!
 @method `dup2:`
 @abstract Converts the object back to a file descriptor.
 @param fd
    file descriptor opened/replaced with.
 @return
    Returns boolean value true when duplication to fd is successful.
 */
- (BOOL)dup2:(int)fd;

/*!
 @method `writeOut:`
 */
- (BOOL)writeOut:(NSString*)path;

/*!
 @method `writeIn:`
 */
- (BOOL)writeIn:(NSString*)path;

@end

#endif /* PROCENVIRONMENT_FDOBJECT_H */
