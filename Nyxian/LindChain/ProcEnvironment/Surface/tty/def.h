/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 mach-port-t

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

#ifndef TTY_DEF_H
#define TTY_DEF_H

#include <LindChain/ProcEnvironment/Surface/obj/kvobject.h>
#include <LindChain/ProcEnvironment/Surface/proc/def.h>
#include <limits.h>
#include <unistd.h>
#include <termios.h>

#define TTY_MAX_RD 4096

#define MASTERFD 0
#define SLAVEFD 1

typedef struct ksurface_tty ksurface_tty_t;

struct ksurface_tty {
    /* object header */
    kvobject_t header;
    
    /* file descriptors */
    int userspacefd[2];     /* ownable by userspace processes */
    int kernelfds[2];       /* owned by the kernel tty driver */
    
    /* userspace file descriptors kernel identifiers */
    uint32_t userspacekcid[2];
    
    /* the thread */
    pthread_t pump_thread;
    int alive;
    
    /* the properties */
    struct termios t;
    struct winsize ws;
    
    /* buffers used by the tty driver */
    char rbuf[TTY_MAX_RD];
    char obuf[TTY_MAX_RD * 2];
    
    /* foreground process group */
    pid_t pgrp;
};

#endif /* TTY_DEF_H */
