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

#import <LindChain/ProcEnvironment/Surface/lock/reflock.h>

void reflock_init(reflock_t *r)
{
    seqlock_init((seqlock_t*)r);
    __atomic_store_n(&r->ref, 0, __ATOMIC_RELAXED);
}

void reflock_lock(reflock_t *r)
{
    seqlock_lock((seqlock_t*)r);
    __atomic_add_fetch(&r->ref, 1, __ATOMIC_ACQ_REL);
}

void reflock_unlock(reflock_t *r)
{
    unsigned long old = __atomic_fetch_sub(&r->ref, 1, __ATOMIC_ACQ_REL);
    if(old == 1) seqlock_unlock((seqlock_t*)r);
}

unsigned long reflock_read_begin(reflock_t *r)
{
    return seqlock_read_begin((seqlock_t*)r);
}

bool reflock_read_retry(reflock_t *r,
                        unsigned long seq)
{
    return seqlock_read_retry((seqlock_t*)r, seq);
}

bool reflock_is_locked(reflock_t *r)
{
    return seqlock_is_locked((seqlock_t*)r);
}
