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

#ifndef RCU_TYPE_GLOBAL_STATE_H
#define RCU_TYPE_GLOBAL_STATE_H

#include <LindChain/ProcEnvironment/Surface/lock/rcu/config.h>
#include <LindChain/ProcEnvironment/Surface/lock/rcu/type/thread_state.h>
#include <pthread.h>

struct rcu_state {
    _Atomic unsigned long current_epoch;
    pthread_mutex_t gp_lock;
    pthread_mutex_t registry_lock;
    rcu_thread_state_t thread_state[RCU_MAX_THREADS];
};

typedef struct rcu_state rcu_state_t;

#endif /* RCU_TYPE_GLOBAL_STATE_H */
