/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 cr4zyengineer

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#ifndef PROCENVIRONMENT_LOCK_H
#define PROCENVIRONMENT_LOCK_H

#include <LindChain/ProcEnvironment/panic.h>
#include <string.h>
#include <errno.h>

#if DEBUG
#define PTHREAD_RWLOCK_DEBUG_IMP_RDLOCK(ptr) do { \
    int _e; \
    do { \
        _e = pthread_rwlock_rdlock(ptr); \
        if(_e == EAGAIN) \
        { \
            sched_yield(); \
        } \
        else if(_e) \
        { \
            environment_panic("lock @ %p failed to rdlock with: %s", ptr, strerror(_e)); \
        } \
    } while (_e == EAGAIN); \
} while(0)
#define PTHREAD_RWLOCK_DEBUG_IMP_WRLOCK(ptr) ({ int _e = pthread_rwlock_wrlock(ptr); if (_e) environment_panic("lock @ %p failed to wrlock with: %s", ptr, strerror(_e)); })
#define PTHREAD_RWLOCK_DEBUG_IMP_UNLOCK(ptr) ({ int _e = pthread_rwlock_unlock(ptr); if (_e) environment_panic("lock @ %p failed to unlock with: %s", ptr, strerror(_e)); })
#else
#define PTHREAD_RWLOCK_DEBUG_IMP_RDLOCK(ptr) do { \
    int _e; \
    do { \
        _e = pthread_rwlock_rdlock(ptr); \
        if(_e == EAGAIN) \
        { \
            sched_yield(); \
        } \
    } while (_e == EAGAIN); \
} while(0)
#define PTHREAD_RWLOCK_DEBUG_IMP_WRLOCK(ptr) pthread_rwlock_wrlock(ptr);
#define PTHREAD_RWLOCK_DEBUG_IMP_UNLOCK(ptr) pthread_rwlock_unlock(ptr);
#endif /* DEBUG */

#define proc_table_rdlock() PTHREAD_RWLOCK_DEBUG_IMP_RDLOCK(&(ksurface->proc_info.struct_lock))
#define proc_table_wrlock() PTHREAD_RWLOCK_DEBUG_IMP_WRLOCK(&(ksurface->proc_info.struct_lock))
#define proc_table_unlock() PTHREAD_RWLOCK_DEBUG_IMP_UNLOCK(&(ksurface->proc_info.struct_lock))

#define tty_table_rdlock() PTHREAD_RWLOCK_DEBUG_IMP_RDLOCK(&(ksurface->tty_info.struct_lock))
#define tty_table_wrlock() PTHREAD_RWLOCK_DEBUG_IMP_WRLOCK(&(ksurface->tty_info.struct_lock))
#define tty_table_unlock() PTHREAD_RWLOCK_DEBUG_IMP_UNLOCK(&(ksurface->tty_info.struct_lock))

#define host_rdlock() PTHREAD_RWLOCK_DEBUG_IMP_RDLOCK(&(ksurface->host_info.struct_lock))
#define host_wrlock() PTHREAD_RWLOCK_DEBUG_IMP_WRLOCK(&(ksurface->host_info.struct_lock))
#define host_unlock() PTHREAD_RWLOCK_DEBUG_IMP_UNLOCK(&(ksurface->host_info.struct_lock))

#define task_rdlock() PTHREAD_RWLOCK_DEBUG_IMP_RDLOCK(&(ksurface->proc_info.task_lock))
#define task_wrlock() PTHREAD_RWLOCK_DEBUG_IMP_WRLOCK(&(ksurface->proc_info.task_lock))
#define task_unlock() PTHREAD_RWLOCK_DEBUG_IMP_UNLOCK(&(ksurface->proc_info.task_lock))

#endif /* PROCENVIRONMENT_LOCK_H */
