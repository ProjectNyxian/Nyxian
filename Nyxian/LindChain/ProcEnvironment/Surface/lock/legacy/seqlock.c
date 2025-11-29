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

#include <LindChain/ProcEnvironment/Surface/lock/legacy/seqlock.h>
#include <LindChain/ProcEnvironment/Surface/extra/relax.h>

void seqlock_init(seqlock_t *s)
{
    spinlock_init((spinlock_t*)s);
    __atomic_store_n(&s->seq, 0, __ATOMIC_RELAXED);
}

void seqlock_lock(seqlock_t *s)
{
    spinlock_lock((spinlock_t*)s);
    __atomic_add_fetch(&s->seq, 1, __ATOMIC_ACQ_REL);
}

void seqlock_unlock(seqlock_t *s)
{
    __atomic_add_fetch(&s->seq, 1, __ATOMIC_ACQ_REL);
    spinlock_unlock((spinlock_t*)s);
}

unsigned long seqlock_read_begin(const seqlock_t *s)
{
    unsigned long seq;
    for(;;)
    {
        seq = __atomic_load_n(&s->seq, __ATOMIC_ACQUIRE);
        if(seq & 1)
        {
            do
            {
                relax();
                seq = __atomic_load_n(&s->seq, __ATOMIC_ACQUIRE);
            }
            while(seq & 1);
        }
        __atomic_thread_fence(__ATOMIC_ACQUIRE);
        if(__atomic_load_n(&s->seq, __ATOMIC_ACQUIRE) == seq)
        {
            return seq;
        }
        relax();
    }
}

bool seqlock_read_retry(const seqlock_t *s,
                        unsigned long seq)
{
    __atomic_thread_fence(__ATOMIC_ACQUIRE);
    return __atomic_load_n(&s->seq, __ATOMIC_ACQUIRE) != seq;
}

bool seqlock_is_locked(const seqlock_t *s)
{
    return spinlock_is_locked((spinlock_t*)s);
}

bool seqlock_trylock(seqlock_t *s)
{
    bool aquired_lock = spinlock_trylock((spinlock_t*)s);
    if(aquired_lock)
    {
        __atomic_add_fetch(&s->seq, 1, __ATOMIC_ACQ_REL);
    }
    return aquired_lock;
}
