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

#import <LindChain/ProcEnvironment/Syscall/payload.h>
#include <mach/mach.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>
#include <unistd.h>

#define SYSCALL_MAX_PAYLOAD     16384
#define SYSCALL_SERVER_THREADS  4
#define SYSCALL_QUEUE_LIMIT     32

/* macro for extremely easy process usage from syscalls */
#define sys_proc_ ((ksurface_proc_t*)(((ksurface_proc_copy_t*)proc_copy)->proc))

/* accessing safe snapshot */
#define sys_proc_copy_ ((ksurface_proc_copy_t*)proc_copy)

/* request message coming from the client */
typedef struct {
    mach_msg_header_t           header;         /* mach message header */
    mach_msg_body_t             body;           /* mach message body which holds information about descriptors */
    mach_msg_ool_descriptor_t   ool;            /* mach message descriptor for arbitary length payloads provided by the guest process MARK: Do not trust guest provided payloads blindly */
    mach_msg_ool_ports_descriptor_t oolp;       /* mach message descriptor for arbitary amount of mach ports provided by the guest process */
    uint32_t                    syscall_num;    /* syscall the guest process wants to call */
    int64_t                     args[6];        /* syscall arguments for general purpose MARK: not for buffers! */
} syscall_request_t;

/* reply message coming from the kernel virtualization layer */
typedef struct {
    mach_msg_header_t           header;         /* mach message header */
    mach_msg_body_t             body;           /* mach message body which holds information about descriptors */
    mach_msg_ool_descriptor_t   ool;            /* mach message descriptor for arbitary length payloads provided by the kernel virtualization layer */
    mach_msg_ool_ports_descriptor_t oolp;       /* mach message descriptor for arbitary amount of macg ports provided by the kernel virtualization layer */
    int64_t                     result;         /* syscall return value for the guest */
    errno_t                     err;            /* errno result value from the syscall */
} syscall_reply_t;

typedef int64_t (*syscall_handler_t)(
    /*
     * holds information about the process identity
     * that made the syscall
     * which is very important, because this is our security
     * ensurace
     */
    void                *proc_copy,

    /*
     * normal syscall arguments
     */
    int64_t             *args,

    /*
     * a special multipurpose argument, a payload
     * the payload is provided by the guest process
     * so please do security checks on it!!!
     */
    uint8_t             *in_payload,
    uint32_t            in_len,

    /*
     * outgoing payload back to the guest process
     */
    uint8_t             **out_payload,
    uint32_t            *out_len,

    /*
     * a special multipurpose argument, a ports payload
     * that is guest provided.
     */
    mach_port_t         *in_ports,
    uint32_t            in_ports_cnt,

    /*
     * outgoing ports back to the guest process
     */
    mach_port_t         **out_ports,
    uint32_t            *out_ports_cnt,

    /*
     * sets errno in the guest process by the client receiving it
     * and setting errno from the reply
     */
    errno_t             *err
);

#define DEFINE_SYSCALL_HANDLER(sysname) int64_t syscall_server_handler_##sysname( \
    void                *proc_copy, \
    int64_t             *args, \
    uint8_t             *in_payload, \
    uint32_t            in_len, \
    uint8_t             **out_payload, \
    uint32_t            *out_len, \
    mach_port_t         *in_ports, \
    uint32_t            in_ports_cnt, \
    mach_port_t         **out_ports, \
    uint32_t            *out_ports_cnt, \
    errno_t             *err \
)

#define GET_SYSCALL_HANDLER(sysname) syscall_server_handler_##sysname

typedef struct syscall_server syscall_server_t;

syscall_server_t *syscall_server_create(void);
void syscall_server_destroy(syscall_server_t *server);
int syscall_server_start(syscall_server_t *server);
void syscall_server_stop(syscall_server_t *server);
mach_port_t syscall_server_get_port(syscall_server_t *server);
void syscall_server_register(syscall_server_t *server, uint32_t syscall_num, syscall_handler_t handler);

#endif /* MACH_SYSCALL_SERVER_H */
