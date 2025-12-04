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

#ifndef MACH_SYSCALL_CLIENT_H
#define MACH_SYSCALL_CLIENT_H

#import <LindChain/ProcEnvironment/Syscall/mach_syscall_server.h>

typedef struct syscall_client syscall_client_t;

syscall_client_t *syscall_client_create(mach_port_t port);
void syscall_client_destroy(syscall_client_t *client);
int64_t syscall_invoke(syscall_client_t *client, uint32_t syscall_num, int64_t args[6], void *in_payload, uint32_t in_len, void *out_payload, uint32_t *out_len);

#endif /* MACH_SYSCALL_CLIENT_H */
