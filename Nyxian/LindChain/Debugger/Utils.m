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

#include "Utils.h"

hw_breakpoint_t hw_breakpoints[6] = {0};
bool singleStepMode = false;

const char *sym_at_address(vm_address_t address)
{
    static char buffer[256];
    Dl_info info;
    if(dladdr((void*)address, &info) && info.dli_sname)
    {
        snprintf(buffer, sizeof(buffer), "%s", info.dli_sname);
        return buffer;
    }
    return "<unknown>";
}

/* https://github.com/opa334/opainject/blob/849bb296ea8bc0643a2966485ea3c3c96ebdcd5b/thread_utils.m#L135 */
kern_return_t suspend_threads_except_for(thread_act_array_t allThreads,
                                         mach_msg_type_number_t threadCount,
                                         thread_act_t exceptForThread)
{
    for(int i = 0; i < threadCount; i++)
    {
        thread_act_t thread = allThreads[i];
        if(thread != exceptForThread)
        {
            thread_suspend(thread);
        }
    }
    
    return KERN_SUCCESS;
}

/* https://github.com/opa334/opainject/blob/849bb296ea8bc0643a2966485ea3c3c96ebdcd5b/thread_utils.m#L146 */
kern_return_t resume_threads_except_for(thread_act_array_t allThreads,
                                        mach_msg_type_number_t threadCount,
                                        thread_act_t exceptForThread)
{
    for(int i = 0; i < threadCount; i++)
    {
        thread_act_t thread = allThreads[i];
        if(thread != exceptForThread)
        {
            thread_resume(thread);
        }
    }
    
    return KERN_SUCCESS;
}

void state_back_trace(arm_thread_state64_t state,
                      uint64_t maxdepth)
{
    stack_frame_t start_frame;
    start_frame.lr = state.__pc;
    start_frame.fp = (void*)state.__fp;
    stack_frame_t *frame = &start_frame;

    int depth = 0;
    while(frame && depth < maxdepth)
    {
        vm_address_t addr = (depth == 0) ? frame->lr : ((uintptr_t)frame->lr - 4);
        const char *name = sym_at_address(addr);
        
        printf("#%d: FP=%p LR=0x%lx (0x%lx) -> %s\n", depth, frame, frame->lr, addr, name);
        
        /* getting next frame */
        stack_frame_t *next_fp = frame->fp;
        
        /* sanity check: FP should be increasing (growing down the stack) */
        if(next_fp && next_fp <= frame)
        {
            break;
        }
            
        /* setting next frame for going further down */
        frame = next_fp;
        depth++;
    }
}

kern_return_t task_thread_index(task_t task,
                                thread_t target,
                                mach_msg_type_number_t *index)
{
    thread_act_array_t threads;
    mach_msg_type_number_t count;

    /* getting list of threads */
    kern_return_t kr = task_threads(task, &threads, &count);
    if(kr != KERN_SUCCESS)
    {
        return kr;
    }

    /* getting index by itterating all threads in task */
    for(mach_msg_type_number_t i = 0; i < count; i++)
    {
        if(threads[i] == target)
        {
            /* found the thread */
            *index = i;
            break;
        }
    }

    /* deallocating all threads again */
    for(mach_msg_type_number_t i = 0; i < count; i++)
    {
        mach_port_deallocate(mach_task_self(), threads[i]);
    }

    return kr;
}

static bool evaluate_condition(uint32_t cond,
                               uint32_t cpsr)
{
    bool n = FLAG_N(cpsr);
    bool z = FLAG_Z(cpsr);
    bool c = FLAG_C(cpsr);
    bool v = FLAG_V(cpsr);
    
    switch(cond & 0xE)
    {   /* ignore bit 0 for initial check */
        case 0x0: return z;                    /* EQ: Z == 1 */
        case 0x2: return c;                    /* CS/HS: C == 1 */
        case 0x4: return n;                    /* MI: N == 1 */
        case 0x6: return v;                    /* VS: V == 1 */
        case 0x8: return c && !z;              /* HI: C == 1 && Z == 0 */
        case 0xA: return n == v;               /* GE: N == V */
        case 0xC: return !z && (n == v);       /* GT: Z == 0 && N == V */
        case 0xE: return true;                 /* AL: Always */
    }
    
    /* handle inverse conditions (bit 0 == 1) */
    if(cond & 1)
    {
        switch (cond & 0xE)
        {
            case 0x0: return !z;               /* NE: Z == 0 */
            case 0x2: return !c;               /* CC/LO: C == 0 */
            case 0x4: return !n;               /* PL: N == 0 */
            case 0x6: return !v;               /* VC: V == 0 */
            case 0x8: return !c || z;          /* LS: C == 0 || Z == 1 */
            case 0xA: return n != v;           /* LT: N != V */
            case 0xC: return z || (n != v);    /* LE: Z == 1 || N != V */
        }
    }
    
    return true;  /* fall back */
}

static int64_t sign_extend(uint64_t value, int bits)
{
    uint64_t sign_bit = 1ULL << (bits - 1);
    if(value & sign_bit)
    {
        return (int64_t)(value | (~0ULL << bits));
    }
    return (int64_t)value;
}

uint64_t get_next_pc(arm_thread_state64_t state)
{
    uint64_t pc = state.__pc;
    uint32_t cpsr = state.__cpsr;
    
    /* read instruction at pc */
    uint32_t inst;
    vm_size_t read_size;
    kern_return_t kr = vm_read_overwrite(mach_task_self(), pc, sizeof(inst), (mach_vm_address_t)&inst, &read_size);
    
    if(kr != KERN_SUCCESS)
    {
        return pc + 4;  /* fallback */
    }
    
    /* RET Xn (1101 0110 0101 1111 0000 00nn nnn0 0000) */
    if((inst & 0xFFFFFC1F) == 0xD65F0000)
    {
        uint32_t rn = (inst >> 5) & 0x1F;
        return state.__x[rn];  /* usually X30 (LR) */
    }
    
    /* RETAA, RETAB (authenticated returns) */
    if(inst == 0xD65F0BFF || inst == 0xD65F0FFF)
    {
        return state.__x[30];  // LR
    }
    
    /* BR Xn (1101 0110 0001 1111 0000 00nn nnn0 0000) */
    if((inst & 0xFFFFFC1F) == 0xD61F0000)
    {
        uint32_t rn = (inst >> 5) & 0x1F;
        return state.__x[rn];
    }
    
    /* BLR Xn (1101 0110 0011 1111 0000 00nn nnn0 0000) */
    if((inst & 0xFFFFFC1F) == 0xD63F0000)
    {
        uint32_t rn = (inst >> 5) & 0x1F;
        return state.__x[rn];
    }
    
    /* B (unconditional branch) - 0001 01ii iiii iiii iiii iiii iiii iiii */
    if((inst & 0xFC000000) == 0x14000000)
    {
        int64_t offset = sign_extend((inst & 0x03FFFFFF), 26) << 2;
        return pc + offset;
    }
    
    /* BL (branch with link) - 1001 01ii iiii iiii iiii iiii iiii iiii */
    if((inst & 0xFC000000) == 0x94000000)
    {
        int64_t offset = sign_extend((inst & 0x03FFFFFF), 26) << 2;
        return pc + offset;
    }
    
    /* B.cond (conditional branch) - 0101 0100 iiii iiii iiii iiii iii0 cccc */
    if((inst & 0xFF000010) == 0x54000000)
    {
        uint32_t cond = inst & 0xF;
        int64_t offset = sign_extend((inst >> 5) & 0x7FFFF, 19) << 2;
        
        if(evaluate_condition(cond, cpsr))
        {
            return pc + offset;  /* taken */
        }
        else
        {
            return pc + 4;       /* not taken */
        }
    }
    
    /* CBZ (compare and branch if zero) - sf 011 010 0 iiiiiiiiiiiiiiiiiii ttttt */
    if((inst & 0x7F000000) == 0x34000000)
    {
        uint32_t rt = inst & 0x1F;
        int64_t offset = sign_extend((inst >> 5) & 0x7FFFF, 19) << 2;
        bool is_64bit = (inst >> 31) & 1;
        
        uint64_t reg_val = state.__x[rt];
        if(!is_64bit)
        {
            reg_val &= 0xFFFFFFFF;  /* use only lower 32 bits */
        }
        
        if(reg_val == 0)
        {
            return pc + offset;  /* taken */
        }
        else
        {
            return pc + 4;       /* not taken */
        }
    }
    
    /* CBNZ (compare and branch if non-zero) - sf 011 010 1 iiiiiiiiiiiiiiiiiii ttttt */
    if((inst & 0x7F000000) == 0x35000000)
    {
        uint32_t rt = inst & 0x1F;
        int64_t offset = sign_extend((inst >> 5) & 0x7FFFF, 19) << 2;
        bool is_64bit = (inst >> 31) & 1;
        
        uint64_t reg_val = state.__x[rt];
        if(!is_64bit)
        {
            reg_val &= 0xFFFFFFFF;  /* use only lower 32 bits */
        }
        
        if(reg_val != 0)
        {
            return pc + offset;  /* taken */
        }
        else
        {
            return pc + 4;       /* not taken */
        }
    }
    
    /* TBZ (test bit and branch if zero) - b5 011 011 0 b40 iiiiiiiiiiiiiii ttttt */
    if((inst & 0x7F000000) == 0x36000000)
    {
        uint32_t rt = inst & 0x1F;
        uint32_t bit_pos = ((inst >> 19) & 0x1F) | ((inst >> 26) & 0x20);
        int64_t offset = sign_extend((inst >> 5) & 0x3FFF, 14) << 2;
        
        uint64_t reg_val = state.__x[rt];
        bool bit_set = (reg_val >> bit_pos) & 1;
        
        if(!bit_set)
        {
            return pc + offset;  /* taken (bit is zero) */
        }
        else
        {
            return pc + 4;       /* not taken */
        }
    }
    
    /* TBNZ (test bit and branch if non-zero) - b5 011 011 1 b40 iiiiiiiiiiiiiii ttttt */
    if((inst & 0x7F000000) == 0x37000000)
    {
        uint32_t rt = inst & 0x1F;
        uint32_t bit_pos = ((inst >> 19) & 0x1F) | ((inst >> 26) & 0x20);
        int64_t offset = sign_extend((inst >> 5) & 0x3FFF, 14) << 2;
        
        uint64_t reg_val = state.__x[rt];
        bool bit_set = (reg_val >> bit_pos) & 1;
        
        if(bit_set)
        {
            return pc + offset;  /* taken (bit is non-zero) */
        }
        else
        {
            return pc + 4;       /* not taken */
        }
    }
    
    /* BR Xn (1101 0110 0001 1111 0000 00nn nnn0 0000) */
    if((inst & 0xFFFFFC1F) == 0xD61F0000)
    {
        uint32_t rn = (inst >> 5) & 0x1F;
        return state.__x[rn];
    }

    /* BRAA, BRAAZ, BRAB, BRABZ (authenticated branches) */
    /* Encoding: 1101 0111 X_X1 1111 0000 10XX XXXX XXXX */
    if((inst & 0xFF0FF800) == 0xD70F0800)
    {
        uint32_t rn = inst & 0x1F;
        return state.__x[rn];
    }

    /* BLR Xn (1101 0110 0011 1111 0000 00nn nnn0 0000) */
    if((inst & 0xFFFFFC1F) == 0xD63F0000)
    {
        uint32_t rn = (inst >> 5) & 0x1F;
        return state.__x[rn];
    }
    
    /* default: sequential instruction */
    return pc + 4;
}

parsed_command_t parse_command(const char *input)
{
    parsed_command_t result = {0};
    char buffer[256];
    strncpy(buffer, input, sizeof(buffer) - 1);
    
    char *token = strtok(buffer, " \t");
    if(token)
    {
        strncpy(result.cmd, token, sizeof(result.cmd) - 1);
    }
    
    while((token = strtok(NULL, " \t")) && result.arg_count < 10)
    {
        strncpy(result.args[result.arg_count++], token, 127);
    }
    
    return result;
}

bool set_hw_breakpoint(thread_t thread, int slot, void *address)
{
    if(slot < 0 || slot >= 6)
    {
        printf("[ndb] Invalid breakpoint slot (0-5)\n");
        return false;
    }
    
    arm_debug_state64_t debug_state;
    mach_msg_type_number_t count = ARM_DEBUG_STATE64_COUNT;
    
    kern_return_t kr = thread_get_state(thread, ARM_DEBUG_STATE64, (thread_state_t)&debug_state, &count);
    if(kr != KERN_SUCCESS)
    {
        printf("[ndb] Failed to get debug state\n");
        return false;
    }
    
    /* set breakpoint address */
    debug_state.__bvr[slot] = (uint64_t)address;
    
    /*
     * enable breakpoint: BCR format
     * bit 0: Enable
     * bits 1-2: PMC (Privilege Mode Control) = 11 (any mode)
     * bits 5-8: BAS (Byte Address Select) = 1111 (all bytes)
     */
    debug_state.__bcr[slot] = 0x1E5;  /* Enabled, any privilege, match all bytes */
    
    kr = thread_set_state(thread, ARM_DEBUG_STATE64, (thread_state_t)&debug_state, count);
    if(kr != KERN_SUCCESS)
    {
        printf("[ndb] Failed to set debug state\n");
        return false;
    }
    
    hw_breakpoints[slot].enabled = true;
    hw_breakpoints[slot].address = address;
    printf("[ndb] Hardware breakpoint %d set at %p\n", slot, address);
    return true;
}

bool clear_hw_breakpoint(thread_t thread, int slot)
{
    if(slot < 0 || slot >= 6) {
        printf("[ndb] Invalid breakpoint slot (0-5)\n");
        return false;
    }
    
    arm_debug_state64_t debug_state;
    mach_msg_type_number_t count = ARM_DEBUG_STATE64_COUNT;
    
    kern_return_t kr = thread_get_state(thread, ARM_DEBUG_STATE64,
                                       (thread_state_t)&debug_state, &count);
    if(kr != KERN_SUCCESS) return false;
    
    debug_state.__bcr[slot] = 0;  /* disable */
    
    kr = thread_set_state(thread, ARM_DEBUG_STATE64, (thread_state_t)&debug_state, count);
    
    hw_breakpoints[slot].enabled = false;
    hw_breakpoints[slot].address = NULL;
    printf("[ndb] Hardware breakpoint %d cleared\n", slot);
    return kr == KERN_SUCCESS;
}

void print_register(const char *name, uint64_t value)
{
    printf("%-4s = 0x%016llx  (%llu)\n", name, value, value);
}

uint64_t* get_register_ptr(arm_thread_state64_t *state, const char *name)
{
    if(strcmp(name, "pc") == 0) return &state->__pc;
    if(strcmp(name, "sp") == 0) return &state->__sp;
    if(strcmp(name, "fp") == 0) return &state->__fp;
    if(strcmp(name, "lr") == 0) return &state->__lr;
    if(strcmp(name, "cpsr") == 0) return (uint64_t*)&state->__cpsr;
    
    /* x0-x28 */
    if(name[0] == 'x' && isdigit(name[1]))
    {
        int reg = atoi(name + 1);
        if(reg >= 0 && reg <= 28) return &state->__x[reg];
    }
    
    return NULL;
}
