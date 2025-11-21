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

#ifndef PROCENVIRONMENT_SEQLOCK
#define PROCENVIRONMENT_SEQLOCK

/* ----------------------------------------------------------------------
 *  Apple API Headers
 * -------------------------------------------------------------------- */
#include <stdbool.h>

/* ----------------------------------------------------------------------
 *  Environment API Headers
 * -------------------------------------------------------------------- */
#include <LindChain/ProcEnvironment/Surface/lock/spinlock.h>

/*!
 @struct seqlock_t
 @abstract
    Sequence lock structure.
 @discussion
    The sequence lock structure is used by the sequence lock api.
 
 */
typedef struct {
    /*! Spinlock of the sequence lock, used mainly for robust synchronisation.  */
    unsigned char lock;
    
    /*! Current sequence.  */
    unsigned long seq;
} seqlock_t;

/*!
 @function seqlock_init
 @abstract Initializes seqlock structure to be used.
 @discussion
    Written to make initialization of a seqlock friendly to all humans.
 @param  s
    Pointer to uninitialized seqlock structure.
 */
void seqlock_init(seqlock_t *s);

/*!
 @function seqlock_lock
 @abstract Locks seqlock.
 @discussion
    Readers will spin till the lock is unlocked and writers will wait till they can aquire the lock, which is also after the lock is unlocked.
 @param  s
    Pointer to seqlock structure.
 */
void seqlock_lock(seqlock_t *s);

/*!
 @function seqlock_unlock
 @abstract Unlocks seqlock.
 @discussion
    Unlocks seqlock, which causes readers to stop spinning unless a writer aquires the lock before they checked the sequence of the seqlock.
 @param  s
    Pointer to seqlock structure.
 */
void seqlock_unlock(seqlock_t *s);

/*!
 @function seqlock_read_begin
 @abstract Starts reading action and returns current sequence.
 @discussion
    Stores thread locally the current sequence to compare it later to in `seqlock_retry(1)`
 @param  s
    Pointer to seqlock structure.
 */
unsigned long seqlock_read_begin(const seqlock_t *s);

/*!
 @function seqlock_read_retry
 @abstract Returns if a read sequence needs to be retried.
 @param  s
    Pointer to seqlock structure.
 @param seq
    Value of saved sequence.
 */
bool seqlock_read_retry(const seqlock_t *s, unsigned long seq);

#endif /* PROCENVIRONMENT_SEQLOCK */
