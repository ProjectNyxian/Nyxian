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

#import <LindChain/ProcEnvironment/Surface/sys/compat/spawn.h>

/* MARK: unfinished syscall */

DEFINE_SYSCALL_HANDLER(spawn)
{
    userspace_pointer_t pidPtr = (userspace_pointer_t)args[0];
    userspace_pointer_t pathPtr = (userspace_pointer_t)args[1];
    userspace_pointer_t argPtr = (userspace_pointer_t)args[2];
    userspace_pointer_t envPtr = (userspace_pointer_t)args[3];
    userspace_pointer_t fdNumPtr = (userspace_pointer_t)args[4];
    
    char *executablePath = mach_syscall_copy_str_in(sys_task_, pathPtr, PATH_MAX);
    
    /* TODO: just do the fucking rest lol, am a eepyhead rn */
    
    free(executablePath);
    sys_return;
}
