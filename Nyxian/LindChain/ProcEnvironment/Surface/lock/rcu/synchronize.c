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

#include <LindChain/ProcEnvironment/Surface/lock/rcu/synchronize.h>
#include <pthread.h>

void synchronize_rcu(rcu_state_t *state)
{
    pthread_mutex_lock(&(state->gp_lock));
    smp_mb();
    unsigned long new_epoch = atomic_fetch_add(&(state->current_epoch), 1) + 1;
    
    for(int i = 0; i < RCU_MAX_THREADS; i++)
    {
        struct rcu_thread_state *ts = &(state->thread_state[i]);
        if(!atomic_load(&ts->active))
        {
            continue;
        }
        
        while(1)
        {
            unsigned int nesting = atomic_load(&ts->rcu_nesting);
            unsigned long epoch = atomic_load(&ts->epoch_seen);
            if(nesting == 0 || epoch >= new_epoch)
            {
                break;
            }
            __asm__ __volatile__("yield" ::: "memory");
        }
    }
    smp_mb();
    pthread_mutex_unlock(&(state->gp_lock));
}
