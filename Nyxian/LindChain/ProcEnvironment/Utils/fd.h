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

#ifndef PROCENVIRONMENT_FD_H
#define PROCENVIRONMENT_FD_H

#import <LindChain/ProcEnvironment/Surface/libkern/bsd/proc_info.h>
#import <LindChain/Private/mach/fileport.h>
#include <mach/mach.h>
#include <stdbool.h>

/*!
 @function `get_all_fds`
 @abstract Gets all file descriptors.
 @discussion
    Gets all file descriptors currently opened in the process.
 */
void get_all_fds(int *numFDs, struct proc_fdinfo **fdinfo);

/*!
 @function `close_all_fd`
 @abstract Closes all file descriptors.
 @discussion
    Closes all file descriptors using libproc.
 */
void close_all_fd(void);

/*!
 @function `fd_is_guarded`
 @abstract Detects if a file descriptor is guarded.
 @return Returns boolean value that indicates guardedness.
 */
bool fd_is_guarded(int fd);

#endif /* PROCENVIRONMENT_FD_H */
