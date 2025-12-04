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

#ifndef MACH_SYSCALL_SERVER_H
#define MACH_SYSCALL_SERVER_H

#include <mach/mach.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <unistd.h>

#define SYSCALL_MAX_PAYLOAD     4096
#define SYSCALL_SERVER_THREADS  4
#define SYSCALL_QUEUE_LIMIT     32

/* macro for extremely easy process usage from syscalls */
#define sys_proc_ ((ksurface_proc_t*)caller->proc)

typedef struct {
    pid_t   pid;
    uid_t   euid;
    gid_t   egid;
    uid_t   ruid;
    gid_t   rgid;
    void    *proc;
} syscall_caller_t;

typedef struct {
    mach_msg_header_t   header;
    uint32_t            syscall_num;
    int64_t             args[6];
    uint32_t            payload_len;
    uint8_t             payload[SYSCALL_MAX_PAYLOAD];
} syscall_request_t;

typedef struct {
    mach_msg_header_t   header;
    int64_t             result;
    errno_t             err;
    uint32_t            payload_len;
    uint8_t             payload[SYSCALL_MAX_PAYLOAD];
} syscall_reply_t;

typedef int64_t (*syscall_handler_t)(
    syscall_caller_t    *caller,
    int64_t             *args,
    uint8_t             *in_payload,
    uint32_t            in_len,
    uint8_t             *out_payload,
    uint32_t            *out_len,
    errno_t             *err
);

#define DEFINE_SYSCALL_HANDLER(sysname) int64_t syscall_server_handler_##sysname(syscall_caller_t *caller, int64_t *args, uint8_t *in_payload, uint32_t in_len, uint8_t *out_payload, uint32_t *out_len, errno_t *err)
#define GET_SYSCALL_HANDLER(sysname) syscall_server_handler_##sysname

typedef struct syscall_server syscall_server_t;

syscall_server_t *syscall_server_create(void);
void syscall_server_destroy(syscall_server_t *server);
int syscall_server_start(syscall_server_t *server);
void syscall_server_stop(syscall_server_t *server);
mach_port_t syscall_server_get_port(syscall_server_t *server);
void syscall_server_register(syscall_server_t *server, uint32_t syscall_num, syscall_handler_t handler);

#endif /* MACH_SYSCALL_SERVER_H */
