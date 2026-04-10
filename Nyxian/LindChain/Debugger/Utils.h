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

#ifndef LINDCHAIN_DEBUGGER_UTILS_H
#define LINDCHAIN_DEBUGGER_UTILS_H

#include <stdlib.h>
#include <mach/mach.h>

/* https://github.com/opa334/opainject/blob/849bb296ea8bc0643a2966485ea3c3c96ebdcd5b/thread_utils.h#L27 */
struct arm64_thread_full_state {
    arm_thread_state64_t    thread;
    arm_exception_state64_t exception;
    arm_neon_state64_t      neon;
    arm_debug_state64_t     debug;
    uint32_t                thread_valid:1,
                            exception_valid:1,
                            neon_valid:1,
                            debug_valid:1,
                            cpmu_valid:1;
};

/* https://github.com/opa334/opainject/blob/849bb296ea8bc0643a2966485ea3c3c96ebdcd5b/thread_utils.h#L39 */
struct arm64_thread_full_state* thread_save_state_arm64(thread_act_t thread);
bool thread_restore_state_arm64(thread_act_t thread, struct arm64_thread_full_state* state);

#endif /* LINDCHAIN_DEBUGGER_UTILS_H */
