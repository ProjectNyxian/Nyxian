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

#ifndef PROCENVIRONMENT_POSIXSPAWN_H
#define PROCENVIRONMENT_POSIXSPAWN_H

/* ----------------------------------------------------------------------
 *  Apple API Headers
 * -------------------------------------------------------------------- */
#import <Foundation/Foundation.h>
#include <spawn.h>

/* ----------------------------------------------------------------------
 *  Environment API Headers
 * -------------------------------------------------------------------- */
#import <LindChain/ProcEnvironment/Object/FDMapObject.h>

/*!
 @typedef environment_posix_spawn_file_actions_t
 @abstract
    An opaque type representing file actions for posix_spawn within the environment API.
 @discussion
    The contents of this type are private and should not be accessed directly. Unless YOU KNOW WHAT YOU DO!
 */
typedef struct {
    FDMapObject *mapObject;
} environment_posix_spawn_file_actions_t;

int environment_posix_spawn(pid_t *process_identifier,
                            const char *path,
                            const environment_posix_spawn_file_actions_t **fa,
                            const posix_spawnattr_t *spawn_attr,
                            char *const argv[],
                            char *const envp[]);

int environment_posix_spawnp(pid_t *process_identifier,
                             const char *path,
                             const environment_posix_spawn_file_actions_t **file_actions,
                             const posix_spawnattr_t *spawn_attr,
                             char *const argv[],
                             char *const envp[]);

int environment_posix_spawn_file_actions_init(environment_posix_spawn_file_actions_t **fa);
int environment_posix_spawn_file_actions_destroy(environment_posix_spawn_file_actions_t **fa);

int environment_posix_spawn_file_actions_adddup2(environment_posix_spawn_file_actions_t **fa, int host_fd, int child_fd);
int environment_posix_spawn_file_actions_addclose(environment_posix_spawn_file_actions_t **fa, int child_fd);

void environment_posix_spawn_init(void);

#endif /* PROCENVIRONMENT_POSIXSPAWN_H */
