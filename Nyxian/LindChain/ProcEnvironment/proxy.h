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
extern syscall_client_t *syscallProxy;

// MARK: Helper symbols that are intended stabilizing the proc environment api proxy wise and reduce the amount of deadlocking in the future

/// Sends the `signal` to the process identified by its `process_identifier`
int environment_proxy_proc_kill_process_identifier(pid_t process_identifier, int signal);

/// Spawns a process using a binary at `path` with `arguments` and `environment` and posix like `file_actions`
pid_t environment_proxy_spawn_process_at_path(NSString *path, NSArray *arguments, NSDictionary *environment, FDMapObject *mapObject);

/// Gets process table
void environment_proxy_getproctable(kinfo_proc_t **pt, uint32_t *pt_cnt);

/// Signs a MachO at a given path
void environment_proxy_sign_macho(NSString *path);

void environment_proxy_set_endpoint_for_service_identifier(NSXPCListenerEndpoint *endpoint, NSString *serviceIdentifier);

NSXPCListenerEndpoint *environment_proxy_get_endpoint_for_service_identifier(NSString *serviceIdentifier);

void environment_proxy_set_snapshot(UIImage *snapshot);

void environment_proxy_waittrap(void);

knyx_proc_t environment_proxy_nyxcopy(pid_t pid);

#endif /* PROCENVIRONMENT_PROXY_H */
