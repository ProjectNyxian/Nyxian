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

#ifndef PROC_USERAPI_DDOSFENCE_H
#define PROC_USERAPI_DDOSFENCE_H

#include <stdatomic.h>
#include <stdint.h>
#include <stdbool.h>

/* Rate limitation */
#define RATE_LIMIT_TOKENS_MAX    10
#define RATE_LIMIT_REFILL_MS     100
#define RATE_LIMIT_TOKENS_INIT   10

/* Rate limitation structure */
typedef struct {
    _Atomic int tokens;
    _Atomic uint64_t last_refill_ms;
} ddos_fence_t;

uint64_t _get_time_ms(void);
void rate_limiter_init(ddos_fence_t *df);
bool rate_limiter_try(ddos_fence_t *df);

#endif /* PROC_USERAPI_DDOSFENCE_H */
