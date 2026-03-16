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

/* https://github.com/apple/darwin-xnu/blob/2ff845c2e033bd0ff64b5b6aa6063a1f8f65aa32/bsd/sys/spawn_internal.h#L352-L360 */
typedef enum {
    PSFA_OPEN = 0,
    PSFA_CLOSE = 1,
    PSFA_DUP2 = 2,
    PSFA_INHERIT = 3,
    PSFA_FILEPORT_DUP2 = 4,
    PSFA_CHDIR = 5,
    PSFA_FCHDIR = 6
} psfa_t;

/* https://github.com/apple/darwin-xnu/blob/2ff845c2e033bd0ff64b5b6aa6063a1f8f65aa32/bsd/sys/spawn_internal.h#L375-L394 */
typedef struct _psfa_action {
    psfa_t  psfaa_type;                         /* file action type */
    union {
        int psfaa_filedes;                  /* fd to operate on */
        mach_port_name_t psfaa_fileport;    /* fileport to operate on */
    };
    union {
        struct {
            int     psfao_oflag;            /* open flags to use */
            mode_t  psfao_mode;             /* mode for open */
            char    psfao_path[PATH_MAX];   /* path to open */
        } psfaa_openargs;
        struct {
            int psfad_newfiledes;           /* new file descriptor to use */
        } psfaa_dup2args;
        struct {
            char    psfac_path[PATH_MAX];   /* path to chdir */
        } psfaa_chdirargs;
    };
} _psfa_action_t;

/* https://github.com/apple/darwin-xnu/blob/2ff845c2e033bd0ff64b5b6aa6063a1f8f65aa32/bsd/sys/spawn_internal.h#L414 */
typedef struct _posix_spawn_file_actions {
    int             psfa_act_alloc;         /* available actions space */
    int             psfa_act_count;         /* count of defined actions */
    _psfa_action_t  psfa_act_acts[];        /* actions array (uses c99) */
} *_posix_spawn_file_actions_t;

int environment_posix_spawn(pid_t *process_identifier, const char *path, const environment_posix_spawn_file_actions_t **fa, const posix_spawnattr_t *spawn_attr, char *const argv[], char *const envp[]);
int environment_posix_spawnp(pid_t *process_identifier, const char *path, const environment_posix_spawn_file_actions_t **fa, const posix_spawnattr_t *spawn_attr, char *const argv[], char *const envp[]);

int environment_posix_spawn_file_actions_init(environment_posix_spawn_file_actions_t **fa);
int environment_posix_spawn_file_actions_destroy(environment_posix_spawn_file_actions_t **fa);

int environment_posix_spawn_file_actions_addopen(environment_posix_spawn_file_actions_t **fa, int child_fd, const char *path, int flags, mode_t mode);
int environment_posix_spawn_file_actions_adddup2(environment_posix_spawn_file_actions_t **fa, int host_fd, int child_fd);
int environment_posix_spawn_file_actions_addclose(environment_posix_spawn_file_actions_t **fa, int child_fd);

void environment_posix_spawn_init(void);

#endif /* PROCENVIRONMENT_POSIXSPAWN_H */
