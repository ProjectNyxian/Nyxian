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

#include <LindChain/ProcEnvironment/Surface/lock/rcu/read.h>
#include <LindChain/ProcEnvironment/Surface/lock/rcu/config.h>

extern __thread int rcu_thread_id;

void rcu_read_lock(rcu_state_t *state)
{
    struct rcu_thread_state *self = &(state->thread_state[rcu_thread_id]);
    unsigned int nesting = atomic_load_explicit(&self->rcu_nesting, __ATOMIC_RELAXED);
    atomic_store_explicit(&self->rcu_nesting, nesting + 1, __ATOMIC_RELAXED);
    smp_mb();
}

void rcu_read_unlock(rcu_state_t *state)
{
    struct rcu_thread_state *self = &(state->thread_state[rcu_thread_id]);
    unsigned int nesting = atomic_load_explicit(&self->rcu_nesting, __ATOMIC_RELAXED);
    smp_mb();
    atomic_store_explicit(&self->rcu_nesting, nesting - 1, __ATOMIC_RELAXED);
    if(nesting == 1)
    {
        atomic_store(&self->epoch_seen, atomic_load(&(state->current_epoch)));
    }
}
