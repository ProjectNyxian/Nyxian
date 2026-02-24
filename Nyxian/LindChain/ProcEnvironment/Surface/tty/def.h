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

#ifndef TTY_DEF_H
#define TTY_DEF_H

#import <LindChain/ProcEnvironment/Surface/obj/kvobject.h>
#import <LindChain/ProcEnvironment/Surface/proc/def.h>
#import <limits.h>
#include    <unistd.h>

typedef struct ksurface_tty ksurface_tty_t;

struct ksurface_tty {
    /* object header */
    kvobject_t header;
    
    /* raw private ksurface api fds */
    int masterfds[2];
    int slavefds[2];
    
    /* tty core owns them */
    int core_masterfd;
    int core_slavefd;
    
    /* file descriptors for usage */
    int masterfd;
    int slavefd;
    uint32_t kslavecid;
    
    /* the thread */
    pthread_t pump_thread;
    int alive;
};

#endif /* TTY_DEF_H */
