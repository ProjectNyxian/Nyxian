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

#include <LindChain/ProcEnvironment/Surface/lock/legacy/spinlock.h>
#include <LindChain/ProcEnvironment/Surface/extra/relax.h>

void spinlock_init(spinlock_t *s)
{
    __atomic_store_n(&s->lock, 0, __ATOMIC_RELAXED);
}

void spinlock_lock(spinlock_t *s)
{
    for(;;)
    {
        while(__atomic_load_n(&s->lock, __ATOMIC_RELAXED) == 1)
        {
            relax();
        }
        if(__atomic_exchange_n(&s->lock, 1, __ATOMIC_ACQUIRE) == 0)
        {
            break;
        }
    }
}

void spinlock_unlock(spinlock_t *s)
{
    __atomic_store_n(&s->lock, 0, __ATOMIC_RELEASE);
}

bool spinlock_is_locked(const spinlock_t *s)
{
    return __atomic_load_n(&s->lock, __ATOMIC_RELAXED);
}

bool spinlock_trylock(spinlock_t *s)
{
    if(__atomic_load_n(&s->lock, __ATOMIC_RELAXED) == 1)
    {
        return false;
    }
    else if(__atomic_exchange_n(&s->lock, 1, __ATOMIC_ACQUIRE) == 0)
    {
        return true;
    }
    else
    {
        return false;
    }
}
