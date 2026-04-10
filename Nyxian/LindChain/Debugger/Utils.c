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

#include "Utils.h"

/* https://github.com/opa334/opainject/blob/849bb296ea8bc0643a2966485ea3c3c96ebdcd5b/thread_utils.m#L14 */
struct arm64_thread_full_state* thread_save_state_arm64(thread_act_t thread)
{
    struct arm64_thread_full_state* s = malloc(sizeof(struct arm64_thread_full_state));
    mach_msg_type_number_t count;
    kern_return_t kr;
    
    count = ARM_THREAD_STATE64_COUNT;
    kr = thread_get_state(thread, ARM_THREAD_STATE64, (thread_state_t) &s->thread, &count);
    s->thread_valid = (kr == KERN_SUCCESS);
    if(kr != KERN_SUCCESS)
    {
        free(s);
        return NULL;
    }
    
    count = ARM_EXCEPTION_STATE64_COUNT;
    kr = thread_get_state(thread, ARM_EXCEPTION_STATE64, (thread_state_t) &s->exception, &count);
    s->exception_valid = (kr == KERN_SUCCESS);
    
    count = ARM_NEON_STATE64_COUNT;
    kr = thread_get_state(thread, ARM_NEON_STATE64, (thread_state_t) &s->neon, &count);
    s->neon_valid = (kr == KERN_SUCCESS);
    
    count = ARM_DEBUG_STATE64_COUNT;
    kr = thread_get_state(thread, ARM_DEBUG_STATE64, (thread_state_t) &s->debug, &count);
    s->debug_valid = (kr == KERN_SUCCESS);
    
    return s;
}

/* https://github.com/opa334/opainject/blob/849bb296ea8bc0643a2966485ea3c3c96ebdcd5b/thread_utils.m#L55 */
bool thread_restore_state_arm64(thread_act_t thread, struct arm64_thread_full_state* state)
{
    struct arm64_thread_full_state *s = (void *) state;
    kern_return_t kr;
    bool success = true;
    
    if(s->thread_valid)
    {
        kr = thread_set_state(thread, ARM_THREAD_STATE64, (thread_state_t) &s->thread, ARM_THREAD_STATE64_COUNT);
    }
    
    if(s->exception_valid)
    {
        kr = thread_set_state(thread, ARM_EXCEPTION_STATE64, (thread_state_t) &s->exception, ARM_EXCEPTION_STATE64_COUNT);
    }
    
    if(s->neon_valid)
    {
        kr = thread_set_state(thread, ARM_NEON_STATE64, (thread_state_t) &s->neon, ARM_NEON_STATE64_COUNT);
    }
    
    if(s->debug_valid)
    {
        kr = thread_set_state(thread, ARM_DEBUG_STATE64, (thread_state_t) &s->debug, ARM_DEBUG_STATE64_COUNT);
    }
    
    free(s);
    return success;
}
