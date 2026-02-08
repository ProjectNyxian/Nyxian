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

typedef struct stack_frame {
    struct stack_frame *fp;
    vm_address_t lr;
} stack_frame_t;

typedef struct {
    bool enabled;
    void *address;
} hw_breakpoint_t;

typedef struct {
    char cmd[64];
    char args[10][128];
    int arg_count;
} parsed_command_t;

extern hw_breakpoint_t hw_breakpoints[6];
extern bool singleStepMode;

/* gets the name of a symbol at the passed address (only in this task, need to write a symbol for task ports) */
const char *sym_at_address(vm_address_t address);

/* https://github.com/opa334/opainject/blob/849bb296ea8bc0643a2966485ea3c3c96ebdcd5b/thread_utils.m#L135 */
kern_return_t suspend_threads_except_for(thread_act_array_t allThreads, mach_msg_type_number_t threadCount, thread_act_t exceptForThread);
kern_return_t resume_threads_except_for(thread_act_array_t allThreads, mach_msg_type_number_t threadCount, thread_act_t exceptForThread);

void state_back_trace(arm_thread_state64_t state, uint64_t maxdepth);

kern_return_t task_thread_index(task_t task, thread_t target, mach_msg_type_number_t *index);

uint64_t get_next_pc(arm_thread_state64_t state);

bool set_hw_breakpoint(thread_t thread, int slot, void *address);
bool clear_hw_breakpoint(thread_t thread, int slot);

parsed_command_t parse_command(const char *input);
void print_register(const char *name, uint64_t value);
uint64_t* get_register_ptr(arm_thread_state64_t *state, const char *name);

#endif /* LINDCHAIN_DEBUGGER_UTILS_H */
