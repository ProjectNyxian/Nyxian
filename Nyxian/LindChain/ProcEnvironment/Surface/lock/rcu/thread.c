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

#include <LindChain/ProcEnvironment/Surface/lock/rcu/thread.h>
#include <LindChain/ProcEnvironment/Surface/lock/rcu/config.h>
#include <pthread.h>
#include <stdbool.h>
#include <stdatomic.h>
#include <stdio.h>

__thread int rcu_thread_id = -1;

int rcu_register_thread(rcu_state_t *state)
{
    if(rcu_thread_id >= 0)
    {
        return 0;
    }
    pthread_mutex_lock(&(state->registry_lock));
    for(int i = 0; i < RCU_MAX_THREADS; i++)
    {
        bool expected = false;
        if(atomic_compare_exchange_strong(&(state->thread_state[i].active), &expected, true))
        {
            rcu_thread_id = i;
            atomic_store(&(state->thread_state[i].rcu_nesting), 0);
            atomic_store(&(state->thread_state[i].epoch_seen), atomic_load(&(state->current_epoch)));
            pthread_mutex_unlock(&(state->registry_lock));
            return 0;
        }
    }
    pthread_mutex_unlock(&(state->registry_lock));
    return -1;
}

void rcu_unregister_thread(rcu_state_t *state)
{
    if (rcu_thread_id < 0) return;
    struct rcu_thread_state *self = &(state->thread_state[rcu_thread_id]);
    unsigned int nesting = atomic_load(&self->rcu_nesting);
    if (nesting != 0)
    {
        fprintf(stderr, "WARNING: rcu_unregister_thread called with nesting=%u\n", nesting);
        atomic_store(&self->rcu_nesting, 0);
    }
    atomic_store(&self->epoch_seen, atomic_load(&(state->current_epoch)));
    smp_mb();
    atomic_store(&self->active, false);
    rcu_thread_id = -1;
}
