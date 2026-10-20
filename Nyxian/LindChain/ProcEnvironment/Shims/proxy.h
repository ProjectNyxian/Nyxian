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

#ifndef PROCENVIRONMENT_PROXY_H
#define PROCENVIRONMENT_PROXY_H

/* ----------------------------------------------------------------------
 *  Apple API Headers
 * -------------------------------------------------------------------- */
#import <Foundation/Foundation.h>

/* ----------------------------------------------------------------------
 *  Environment API Headers
 * -------------------------------------------------------------------- */
#import <LindChain/ProcEnvironment/Server/ServerProtocol.h>

// Applicable for child process
extern NSObject<ServerProtocol> *hostProcessProxy;

// MARK: Helper symbols that are intended stabilizing the proc environment api proxy wise and reduce the amount of deadlocking in the future

/// Spawns a process using a binary at `path` with `arguments` and `environment` and posix like `file_actions`
int64_t environment_proxy_spawn_process_at_path(NSString *path, NSArray *arguments, NSDictionary *environment, PEFileTable *fileTable, NSString *workingDirectory, short spawnFlags, pid_t spawnPgroup);

void environment_proxy_set_snapshot(UIImage *snapshot);

#endif /* PROCENVIRONMENT_PROXY_H */
