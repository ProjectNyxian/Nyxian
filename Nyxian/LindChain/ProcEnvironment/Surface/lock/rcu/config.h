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

#ifndef RCU_CONFIG_H
#define RCU_CONFIG_H

#include <stdatomic.h>

#define RCU_MAX_THREADS 128
#define RCU_CACHE_LINE_SIZE 64

#define barrier() __asm__ __volatile__("" : : : "memory")
#define smp_mb() __sync_synchronize()
#define smp_wmb() __atomic_thread_fence(__ATOMIC_RELEASE)
#define smp_rmb() __atomic_thread_fence(__ATOMIC_ACQUIRE)
#define smp_read_barrier_depends() barrier()

#define rcu_dereference(p) ({                                   \
    typeof(p) _________p1 = (*(volatile typeof(p) *)&(p));      \
    smp_read_barrier_depends();                                 \
    (_________p1);                                              \
})

#define rcu_assign_pointer(p, v) do {                           \
    smp_wmb();                                                  \
    (p) = (v);                                                  \
} while (0)

#endif /* RCU_CONFIG_H */
