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

#import <LindChain/LiveContainer/utils.h>

#define ASM(...) __asm__(#__VA_ARGS__)

// Originated from _kernelrpc_mach_vm_protect_trap
ASM(
.global _builtin_vm_protect \n
_builtin_vm_protect:     \n
    mov x16, #-0xe       \n
    svc #0x80            \n
    ret
);

void __assert_rtn(const char* func, const char* file, int line, const char* failedexpr) {
    [NSException raise:NSInternalInconsistencyException format:@"Assertion failed: (%s), file %s, line %d.\n", failedexpr, file, line];
    abort(); // silent compiler warning
}

// https://github.com/pinauten/PatchfinderUtils/blob/master/Sources/CFastFind/CFastFind.c
//
//  CFastFind.c
//  CFastFind
//
//  Created by Linus Henze on 2021-10-16.
//  Copyright © 2021 Linus Henze. All rights reserved.
//

/**
 * Emulate an adrp instruction at the given pc value
 * Returns adrp destination
 */
uint64_t aarch64_emulate_adrp(uint32_t instruction, uint64_t pc) {
    // Check that this is an adrp instruction
    if ((instruction & 0x9F000000) != 0x90000000) {
        return 0;
    }
    
    // Calculate imm from hi and lo
    int32_t imm_hi_lo = (instruction & 0xFFFFE0) >> 3;
    imm_hi_lo |= (instruction & 0x60000000) >> 29;
    if (instruction & 0x800000) {
        // Sign extend
        imm_hi_lo |= 0xFFE00000;
    }
    
    // Build real imm
    int64_t imm = ((int64_t) imm_hi_lo << 12);
    
    // Emulate
    return (pc & ~(0xFFFULL)) + imm;
}

/**
 * Emulate an adrp and ldr instruction at the given pc value
 * Returns destination
 */

uint64_t aarch64_emulate_adrp_ldr(uint32_t instruction, uint32_t ldrInstruction, uint64_t pc) {
    uint64_t adrp_target = aarch64_emulate_adrp(instruction, pc);
    if (!adrp_target) {
        return 0;
    }
    
    if ((instruction & 0x1F) != ((ldrInstruction >> 5) & 0x1F)) {
        return 0;
    }
    
    if ((ldrInstruction & 0xFFC00000) != 0xF9400000) {
        return 0;
    }
    
    uint32_t imm12 = ((ldrInstruction >> 10) & 0xFFF) << 3;
    
    // Emulate
    return adrp_target + (uint64_t) imm12;
}
