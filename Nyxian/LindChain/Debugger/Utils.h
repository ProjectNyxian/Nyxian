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

#ifndef LINDCHAIN_DEBUGGER_UTILS_H
#define LINDCHAIN_DEBUGGER_UTILS_H

#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include <dlfcn.h>
#include <mach/mach.h>
#include <mach/exc.h>
#include <mach/exception.h>
#include <mach/exception_types.h>
#include <mach/thread_act.h>
#include <mach/thread_state.h>
#import <Foundation/Foundation.h>
#import <LindChain/Decompiler/Decompiler.h>

#define FLAG_N(cpsr) (((cpsr) >> 31) & 1)
#define FLAG_Z(cpsr) (((cpsr) >> 30) & 1)
#define FLAG_C(cpsr) (((cpsr) >> 29) & 1)
#define FLAG_V(cpsr) (((cpsr) >> 28) & 1)

#define ARM64_MAX_HW_BREAKPOINTS 16

#define ARM64_BCR_ENABLE        (1u << 0)
#define ARM64_BCR_TYPE_EXECUTE  (0u << 1)
#define ARM64_BCR_TYPE_IGNORE   (0x3 << 1)

typedef struct stack_frame {
    struct stack_frame *fp;
    vm_address_t lr;
} stack_frame_t;

typedef enum {
    PARSED_COMMAND_ARG_TYPE_STRING,
    PARSED_COMMAND_ARG_TYPE_DECIMAL,
    PARSED_COMMAND_ARG_TYPE_HEXADECIMAL,
    PARSED_COMMAND_ARG_TYPE_BINARY
} parsed_command_arg_type_t;

typedef struct {
    char cmd[64];
    char args[10][128];
    parsed_command_arg_type_t arg_types[10];
    unsigned long long arg_values[10];
    int arg_count;
} parsed_command_t;

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

parsed_command_t parse_command(const char *input);
parsed_command_arg_type_t parse_arg_type(const char *arg);
unsigned long long parse_number(const char *str, parsed_command_arg_type_t type);

/* gets the name of a symbol at the passed address (only in this task, need to write a symbol for task ports) */
const char *sym_at_address(vm_address_t address);

/* https://github.com/opa334/opainject/blob/849bb296ea8bc0643a2966485ea3c3c96ebdcd5b/thread_utils.h#L45 */
kern_return_t suspend_threads_except_for(thread_act_array_t allThreads, mach_msg_type_number_t threadCount, thread_act_t exceptForThread);
kern_return_t resume_threads_except_for(thread_act_array_t allThreads, mach_msg_type_number_t threadCount, thread_act_t exceptForThread);

/* https://github.com/opa334/opainject/blob/849bb296ea8bc0643a2966485ea3c3c96ebdcd5b/thread_utils.h#L39 */
struct arm64_thread_full_state* thread_save_state_arm64(thread_act_t thread);
bool thread_restore_state_arm64(thread_act_t thread, struct arm64_thread_full_state* state);

void state_back_trace(struct arm64_thread_full_state *state, uint64_t maxdepth);

kern_return_t task_thread_index(task_t task, thread_t target, mach_msg_type_number_t *index);

uint64_t get_next_pc(struct arm64_thread_full_state *state);
bool pc_at_software_breakpoint(struct arm64_thread_full_state *state);

bool set_hw_breakpoint(struct arm64_thread_full_state *state, int slot, vm_address_t address);
bool clear_hw_breakpoint(struct arm64_thread_full_state *state, int slot);

void over_step_mark_hw_breakpoint(struct arm64_thread_full_state *state, int slot);
bool was_over_step_mark_hw_breakpoint(struct arm64_thread_full_state *state);

uint8_t arm64_find_hw_breakpoint_slot_for_pc(const struct arm64_thread_full_state *state);

uint64_t* get_register_ptr(struct arm64_thread_full_state *state, const char *name);

bool is_enabled_mdscr_single_step(struct arm64_thread_full_state *state);
bool enable_mdscr_single_step(struct arm64_thread_full_state *state);
bool flick_mdscr_single_step(struct arm64_thread_full_state *state);

#endif /* LINDCHAIN_DEBUGGER_UTILS_H */
