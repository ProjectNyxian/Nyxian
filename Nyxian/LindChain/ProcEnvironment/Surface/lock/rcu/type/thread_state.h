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

#ifndef RCU_TYPE_THREAD_STATE_H
#define RCU_TYPE_THREAD_STATE_H

#include <LindChain/ProcEnvironment/Surface/lock/rcu/config.h>
#include <stdbool.h>

struct rcu_thread_state {
    _Atomic unsigned int rcu_nesting;
    _Atomic unsigned long epoch_seen;
    _Atomic bool active;
    char padding[RCU_CACHE_LINE_SIZE - sizeof(_Atomic unsigned int)
                                 - sizeof(_Atomic unsigned long)
                                 - sizeof(_Atomic bool)];
} __attribute__((aligned(RCU_CACHE_LINE_SIZE)));

typedef struct rcu_thread_state rcu_thread_state_t;

#endif /* RCU_TYPE_THREAD_STATE_H */
