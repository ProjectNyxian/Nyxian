/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2025 - 2026 emexlab
 Copyright (C) 2026 semvis123

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

#ifndef LIBKERN_SYS_CORE_H
#define LIBKERN_SYS_CORE_H

#include <LindChain/ProcEnvironment/Surface/libkern/sys/worker.h>
#include <os/lock.h>
#include <stdint.h>

#define SYSCALL_QUEUE_LIMIT     32
#define SYSCALL_HANDLERS_LIMIT  UINT16_MAX

struct syscall_server {
    mach_port_t port;
    pthread_t *threads;
    int threads_cnt;
    atomic_flag init_once;
    os_unfair_lock lock;
    syscall_handler_t handlers[SYSCALL_HANDLERS_LIMIT]; /* for performance reasons this array has to stay flat */
};

syscall_server_t *syscall_server_create(void);
int syscall_server_start(syscall_server_t *server);

void syscall_server_register(syscall_server_t *server, uint32_t syscall_num, syscall_handler_t handler);
syscall_handler_t syscall_server_get_handler(syscall_server_t *server, uint32_t syscall_num);

mach_port_t syscall_server_get_port(syscall_server_t *server);

#endif /* LIBKERN_SYS_CORE_H */
