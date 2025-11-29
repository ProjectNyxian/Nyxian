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

// MARK: Helper symbols that are intended stabilizing the proc environment api proxy wise and reduce the amount of deadlocking in the future

/// Sends a task port to the host application to hand it to other requesting processes
void environment_proxy_tfp_send_port_object(TaskPortObject *port) API_AVAILABLE(ios(26.0));

/// Get a task port from the host application that a other process has handed in using `environment_proxy_tfp_send_port_object(TaskPortObject *port)`
TaskPortObject *environment_proxy_tfp_get_port_object_for_process_identifier(pid_t process_identifier) API_AVAILABLE(ios(26.0));

/// Sends the `signal` to the process identified by its `process_identifier`
int environment_proxy_proc_kill_process_identifier(pid_t process_identifier, int signal);

/// Spawns a process using a binary at `path` with `arguments` and `environment` and posix like `file_actions`
pid_t environment_proxy_spawn_process_at_path(NSString *path, NSArray *arguments, NSDictionary *environment, FDMapObject *mapObject);

/// Sets process credential
int environment_proxy_setprocinfo(ProcessInfo info, unsigned int identifier);

/// Gets process credential
unsigned long environment_proxy_getprocinfo(ProcessInfo info);

/// Signs a MachO at a given path
void environment_proxy_sign_macho(NSString *path);

void environment_proxy_set_endpoint_for_service_identifier(NSXPCListenerEndpoint *endpoint, NSString *serviceIdentifier);

NSXPCListenerEndpoint *environment_proxy_get_endpoint_for_service_identifier(NSString *serviceIdentifier);

void environment_proxy_set_snapshot(UIImage *snapshot);

void environment_proxy_waittrap(void);

#endif /* PROCENVIRONMENT_PROXY_H */
