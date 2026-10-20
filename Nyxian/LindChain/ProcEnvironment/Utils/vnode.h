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

#ifndef __VNODE_H
#define __VNODE_H

#include <stdbool.h>

/* very efficient vnode tricks :3 */
bool vnode_refresh_with_path(const char* path);
bool vnode_recover_with_fd_to_path(int fd, const char *path);

/*
 * stuff to help the trust API with
 * atomatically inode tagged file
 * descriptors that when closed via
 * this API will efficiently update
 * the guest accessible path.
 */
int vnode_inaccessible_open(const char *path, int flg);
int vnode_inaccessible_close(int fd, bool refresh);
int vnode_inaccessible_reopen(int *fd);

#endif /* __VNODE_H */
