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

#ifndef PEFILEHANDLE_H
#define PEFILEHANDLE_H

/* ----------------------------------------------------------------------
 *  Apple API Headers
 * -------------------------------------------------------------------- */
#import <Foundation/Foundation.h>
#import <LindChain/Private/mach/fileport.h>

/* ----------------------------------------------------------------------
 *  Class Declarations
 * -------------------------------------------------------------------- */

/*!
 @class `PEFileHandle`
 @abstract Manages a single file descriptor.
 @discussion
    `PEFileHandle` provides an Objective-C interface for copying,
    applying, and manipulating the file descriptor of a process.
    It is designed to be passed across XPC boundaries and supports
    `NSSecureCoding` for safe serialization.
 */
@interface PEFileHandle : NSObject <NSSecureCoding,NSCopying>

/*!
 @property `fd`
 @abstract The underlying XPC object representing the file descriptor.
 @discussion
    This property is typically managed internally by `PEFileHandle`
    and should not be modified directly by clients.
 */
@property (nonatomic,strong) NSObject<OS_xpc_object> *fd;

/*!
 @method `handleForFileDescriptor:`
 @abstract Creates a object for a file descriptor.
 @param fd
    file descriptor at wish to be converted to a `PEFileHandle`.
 @return
    A instance that is referencing the current file descriptor passed.
 */
+ (instancetype)handleForFileDescriptor:(int)fd;

/*!
 @method `handleForFilePort:`
 @abstract Creates a object for a file descriptor.
 @param fp
    file port at wish to be converted to a `PEFileHandle`.
 @return
    A instance that is referencing the current file descriptor passed.
 */
+ (instancetype)handleForFilePort:(fileport_t)fp;

/*!
 @method `objectForFileAtPath:withFlags:withPermissions:`
 */
+ (instancetype)handleForFileAtPath:(NSString*)path withFlags:(int)flags withPermissions:(int)perm;

/*!
 @method `objectForFileAtPath:withFlags:`
 */
+ (instancetype)handleForFileAtPath:(NSString*)path withFlags:(int)flags;

/*!
 @method `objectForFileAtPath:`
 */
+ (instancetype)handleForFileAtPath:(NSString*)path;

/*!
 @method `setFileDescriptor:`
 @abstract Sets file descriptor to a other file descriptor in the object.
 @param fd
    file descriptor at wish as a replacement.
 */
- (void)setFileDescriptor:(int)fd;

/*!
 @method `extractFileDescriptor`
 @abstract Converts the `PEFileHandle` back to a file descriptor.
 @return
    Returns file descriptor if extraction is successful.
 */
- (int)extractFileDescriptor;

/*!
 @method `extractFileDescriptorToLoc:`
 @abstract Converts the object back to a file descriptor at a wished descriptor identifier.
 @param loc
    file descriptor opened/replaced with.
 @return
    Returns boolean value true when extraction to fd is successful.
 */
- (BOOL)extractFileDescriptorToLoc:(int)loc;

/*!
 @method `writeOut:`
 */
- (BOOL)writeOut:(NSString*)path;

/*!
 @method `writeIn:`
 */
- (BOOL)writeIn:(NSString*)path;

@end

#endif /* PEFILEHANDLE_H */
