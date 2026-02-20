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

#ifndef KVOBJECT_SEM_H
#define KVOBJECT_SEM_H

#include <mach/mach.h>

#import <LindChain/ProcEnvironment/Surface/return.h>
#import <LindChain/ProcEnvironment/Surface/obj/defs.h>

ksurface_return_t kvobject_register_sem(kvobject_strong_t *kvo, kvevent_type_t type, uint64_t *token, semaphore_t *sem_port);

#endif /* KVOBJECT_SEM_H */
