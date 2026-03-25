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

#ifndef PROCENVIRONMENT_FD_H
#define PROCENVIRONMENT_FD_H

#import <LindChain/LiveContainer/Tweaks/libproc.h>
#import <LindChain/Private/mach/fileport.h>
#include <mach/mach.h>
#include <stdbool.h>

#define FD_QUEUE_IN 0
#define FD_QUEUE_OUT 1

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

/*!
 @function `fd_queue_create`
 */
int fd_queue_create(int *q);

/*!
 @function `fd_queue_append_fp`
 */
int fd_queue_append_fp(int inq, fileport_t fp, int mfd);

/*!
 @function `fd_queue_append_fd`
 */
int fd_queue_append_fd(int inq, int fd, int mfd);

/*!
 @function `fd_queue_apply`
 */
int fd_queue_apply(int outq);

#endif /* PROCENVIRONMENT_FD_H */
