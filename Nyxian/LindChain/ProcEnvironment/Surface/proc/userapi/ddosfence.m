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

#import <LindChain/ProcEnvironment/Surface/proc/userapi/ddosfence.h>
#include <time.h>

uint64_t _get_time_ms(void)
{
    struct timespec ts;
    clock_gettime(CLOCK_MONOTONIC, &ts);
    return ts.tv_sec * 1000ULL + ts.tv_nsec / 1000000ULL;
}

void rate_limiter_init(ddos_fence_t *df)
{
    atomic_store(&df->tokens, RATE_LIMIT_TOKENS_INIT);
    atomic_store(&df->last_refill_ms, _get_time_ms());
}

bool rate_limiter_try(ddos_fence_t *df)
{
    uint64_t now = _get_time_ms();
    uint64_t last = atomic_load(&df->last_refill_ms);
    
    uint64_t elapsed = now - last;
    int refill = (int)(elapsed / RATE_LIMIT_REFILL_MS);
    
    if(refill > 0)
    {
        if(atomic_compare_exchange_weak(&df->last_refill_ms, &last, now))
        {
            int current = atomic_load(&df->tokens);
            int new_tokens = current + refill;
            if(new_tokens > RATE_LIMIT_TOKENS_MAX)
            {
                new_tokens = RATE_LIMIT_TOKENS_MAX;
            }
            atomic_store(&df->tokens, new_tokens);
        }
    }
    
    int tokens = atomic_load(&df->tokens);
    while(tokens > 0)
    {
        if (atomic_compare_exchange_weak(&df->tokens, &tokens, tokens - 1)) {
            return true;
        }
    }
    
    return false;
}
