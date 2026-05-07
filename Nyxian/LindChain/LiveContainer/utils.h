/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2023 - 2026 LiveContainer
 Copyright (C) 2026 mach-port-t

 This file is part of LiveContainer.

 LiveContainer is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 LiveContainer is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#ifndef LIVECONTAINER_UTILS_H
#define LIVECONTAINER_UTILS_H

#import <Foundation/Foundation.h>
#include <mach-o/loader.h>
#include <objc/runtime.h>
#include <os/lock.h>

const char **_CFGetProgname(void);
const char **_CFGetProcessPath(void);
int _NSGetExecutablePath(char* buf, uint32_t* bufsize);
void os_unfair_recursive_lock_lock_with_options(void* lock, uint32_t options);
void os_unfair_recursive_lock_unlock(void* lock);
bool os_unfair_recursive_lock_trylock(void* lock);
bool os_unfair_recursive_lock_tryunlock4objc(void* lock);

kern_return_t builtin_vm_protect(mach_port_name_t task, mach_vm_address_t address, mach_vm_size_t size, boolean_t set_max, vm_prot_t new_prot);

uint64_t aarch64_emulate_adrp_ldr(uint32_t instruction, uint32_t ldrInstruction, uint64_t pc);

#endif /* LIVECONTAINER_UTILS_H */
