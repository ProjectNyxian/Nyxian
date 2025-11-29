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

#import <LindChain/ProcEnvironment/Surface/lock/legacy/seqlock.h>

typedef struct {
    unsigned char lock;
    unsigned long seq;
    unsigned long ref;
    unsigned long tid;
} reflock_t;

void reflock_init(reflock_t *r);
void reflock_lock(reflock_t *r);
void reflock_unlock(reflock_t *r);
unsigned long reflock_read_begin(reflock_t *r);
bool reflock_read_retry(reflock_t *r, unsigned long seq);
bool reflock_is_locked(reflock_t *r);
bool reflock_is_locked_by_machthreadself(reflock_t *r);
