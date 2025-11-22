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

#ifndef PROCENVIRONMENT_SPINLOCK
#define PROCENVIRONMENT_SPINLOCK

/* ----------------------------------------------------------------------
 *  Apple API Headers
 * -------------------------------------------------------------------- */
#include <stdbool.h>

/*!
 @struct spinlock_t
 @abstract
    Spinlock structure.
 @discussion
    The spinlock structure is used by the spinlock api.
 
 */
typedef struct {
    
    /*! Indicator if the spinlock is currently locked or unlocked*/
    unsigned char lock;
} spinlock_t;

/*!
 @function spinlock_init
 @abstract Initializes spinlock structure to be used.
 @discussion
    Written to make initialization of a spinlock friendly to all humans.
 @param  s
    Pointer to uninitialized spinlock structure.
 */
void spinlock_init(spinlock_t *s);

/*!
 @function spinlock_lock
 @abstract Locks spinlock.
 @discussion
    A spinlock can be locked when no one holds the lock, if someone holds the lock it will spin till the lock is released(unlocked).
 @param  s
    Pointer to spinlock structure.
 */
void spinlock_lock(spinlock_t *s);

/*!
 @function spinlock_unlock
 @abstract Unlocks spinlock.
 @discussion
    A spinlock can be released(unlocked) and in that case the next process or thread can lock it.
 @param  s
    Pointer to spinlock structure.
 */
void spinlock_unlock(spinlock_t *s);

bool spinlock_is_locked(const spinlock_t *s);

#endif /* PROCENVIRONMENT_SPINLOCK */
