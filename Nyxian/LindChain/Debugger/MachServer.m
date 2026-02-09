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

#import <Foundation/Foundation.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <mach/exc.h>
#include <mach/exception.h>
#include <mach/exception_types.h>
#include <mach/thread_state.h>
#import <LindChain/ProcEnvironment/syscall.h>
#include "litehook.h"
#include "Utils.h"
#include <termios.h>

void debugger_loop(thread_t thread, struct arm64_thread_full_state *state)
{
    int shouldEcho = isatty(STDIN_FILENO);
    
    if(shouldEcho)
    {
        tcflush(STDIN_FILENO, TCIFLUSH);
    }
    else
    {
        int flags = fcntl(STDIN_FILENO, F_GETFL, 0);
        fcntl(STDIN_FILENO, F_SETFL, flags | O_NONBLOCK);
            
        char discard[256];
        while(read(STDIN_FILENO, discard, sizeof(discard)) > 0);
            
        fcntl(STDIN_FILENO, F_SETFL, flags);
    }
    
    while(1)
    {
        printf("[ndb] >>> ");
        fflush(stdout);
        
        char command[256];
        int i = 0;
        char c;
        
        while(i < 255)
        {
            ssize_t n = read(STDIN_FILENO, &c, 1);
            if(n <= 0) break;
            if(c == '\n') break;
            if(c == '\r') break;
            if(c == 127 || c == 8)
            {
                if(i > 0)
                {
                    i--;
                    if(shouldEcho) write(STDOUT_FILENO, "\b \b", 3);
                }
                continue;
            }
            if(shouldEcho) write(STDOUT_FILENO, &c, 1);
            command[i++] = c;
        }
        command[i] = '\0';
        
        printf("\n");
        fflush(stdout);
        
        if(strlen(command) == 0) continue;
        
        parsed_command_t cmd = parse_command(command);
        
        if(strcmp(cmd.cmd, "bt") == 0)
        {
            int depth = 20;
            
            if(cmd.arg_count > 0 && cmd.arg_types[0] != PARSED_COMMAND_ARG_TYPE_STRING)
            {
                depth = (int)cmd.arg_values[0];
                if(depth <= 0) depth = 20;
            }
            
            state_back_trace(state, depth);
        }
        else if(strcmp(cmd.cmd, "reg") == 0 || strcmp(cmd.cmd, "registers") == 0)
        {
            if(cmd.arg_count == 0)
            {
                printf("\n=== general purpose registers ===\n");
                for(int i = 0; i < 29; i++)
                {
                    printf("x%-2d = 0x%016llx  ", i, state->thread.__x[i]);
                    if(i % 2 == 1) printf("\n");
                }
                printf("\n=== special registers ===\n");
                printf("fp   = 0x%016llx (%lld)\n", state->thread.__fp, state->thread.__fp);
                printf("lr   = 0x%016llx (%lld)\n", state->thread.__lr, state->thread.__lr);
                printf("sp   = 0x%016llx (%lld)\n", state->thread.__sp, state->thread.__lr);
                printf("pc   = 0x%016llx  (%s)\n", state->thread.__pc, sym_at_address(state->thread.__pc));
                printf("cpsr = 0x%08x\n", state->thread.__cpsr);
            }
            else if(cmd.arg_count == 1)
            {
                uint64_t *reg = get_register_ptr(state, cmd.args[0]);
                if(reg)
                {
                    printf("%s   = 0x%016llx\n", cmd.args[0], *reg);
                }
                else
                {
                    printf("unknown register: %s\n", cmd.args[0]);
                }
            }
            else if(cmd.arg_count == 2)
            {
                uint64_t *reg = get_register_ptr(state, cmd.args[0]);
                uint64_t value = 0;
                if(reg)
                {
                    if(cmd.arg_types[1] == PARSED_COMMAND_ARG_TYPE_STRING)
                    {
                        value = (uint64_t)dlsym(RTLD_DEFAULT, cmd.args[1]);
                        if(value == 0)
                        {
                            printf("unknown symbol: \"%s\"\n", cmd.args[1]);
                            continue;
                        }
                    }
                    else
                    {
                        value = cmd.arg_values[1];
                    }
                    
                    *reg = value;
                    
                    printf("%s = 0x%llx\n", cmd.args[0], value);
                }
                else
                {
                    printf("unknown register: %s\n", cmd.args[0]);
                }
            }
            else
            {
                /* TODO: print usage description for reg */
            }
        }
        else if(strcmp(cmd.cmd, "break") == 0 || strcmp(cmd.cmd, "b") == 0)
        {
            if(cmd.arg_count == 0)
            {
                printf("\n=== hardware breakpoints ===\n");
                for(int i = 0; i < 6; i++)
                {
                    if(hw_breakpoints[i].enabled)
                    {
                        printf("%d: 0x%016llx (%s)\n", i, (uint64_t)hw_breakpoints[i].address, sym_at_address((vm_address_t)hw_breakpoints[i].address));
                    }
                    else
                    {
                        printf("%d: <disabled>\n", i);
                    }
                }
            }
            else if(cmd.arg_count == 2)
            {
                int slot = atoi(cmd.args[0]);
                
                vm_address_t value;
                if(cmd.arg_types[1] == PARSED_COMMAND_ARG_TYPE_STRING)
                {
                    value = (uint64_t)dlsym(RTLD_DEFAULT, cmd.args[1]);
                    if(value == 0)
                    {
                        printf("unknown symbol: \"%s\"\n", cmd.args[1]);
                        continue;
                    }
                }
                else
                {
                    value = cmd.arg_values[1];
                }
                
                set_hw_breakpoint(state, slot, value);
            }
            else
            {
                printf("usage: break <slot> <address>\n");
            }
        }
        else if(strcmp(cmd.cmd, "delete") == 0 || strcmp(cmd.cmd, "d") == 0)
        {
            if(cmd.arg_count == 1)
            {
                int slot = atoi(cmd.args[0]);
                clear_hw_breakpoint(state, slot);
            }
            else
            {
                printf("usage: delete <slot>\n");
            }
        }
        else if(strcmp(cmd.cmd, "x") == 0 || strcmp(cmd.cmd, "examine") == 0)
        {
            if(cmd.arg_count >= 1)
            {
                void *addr = (void*)strtoull(cmd.args[0], NULL, 0);
                int count = 16;
                if(cmd.arg_count >= 2) count = atoi(cmd.args[1]);
                
                printf("\n=== memory at %p ===\n", addr);
                uint8_t *ptr = (uint8_t*)addr;
                for(int i = 0; i < count; i++)
                {
                    if(i % 16 == 0) printf("%p: ", ptr + i);
                    printf("%02x ", ptr[i]);
                    if(i % 16 == 15) printf("\n");
                }
                if(count % 16 != 0) printf("\n");
            }
            else
            {
                printf("usage: x <address> [count]\n");
            }
        }
        else if(strcmp(cmd.cmd, "disas") == 0 || strcmp(cmd.cmd, "disassemble") == 0)
        {
            if(cmd.arg_count == 0)
            {
                printf("%s(%p):\n%s\n", sym_at_address(state->thread.__pc), (void*)state->thread.__pc, [[Decompiler getDecompiledCodeBuffer:state->thread.__pc] UTF8String]);
            }
            else
            {
                void *addr = (void*)state->thread.__pc;
                int count = 10;
                
                if(cmd.arg_count >= 1)
                {
                    if(cmd.arg_types[1] == PARSED_COMMAND_ARG_TYPE_STRING)
                    {
                        addr = dlsym(RTLD_DEFAULT, cmd.args[0]);
                        if(addr == NULL)
                        {
                            printf("unknown symbol: \"%s\"\n", cmd.args[0]);
                            continue;
                        }
                        
                        printf("%s(%p):\n%s\n", cmd.args[0], addr, [[Decompiler getDecompiledCodeBuffer:(uint64_t)addr] UTF8String]);
                        continue;
                    }
                    else
                    {
                        addr = (void*)cmd.arg_values[0];
                        
                        if(cmd.arg_count >= 2)
                        {
                            count = (int)cmd.arg_values[1];
                        }
                        
                        printf("%p:\n%s\n", addr, [[Decompiler decompileBinary:addr withSize:count] UTF8String]);
                    }
                }
            }
        }
        else if(strcmp(cmd.cmd, "lookup") == 0 || strcmp(cmd.cmd, "l") == 0)
        {
            if(cmd.arg_count >= 1)
            {
                void *sym = dlsym(RTLD_DEFAULT, cmd.args[0]);
                printf("%s => %p\n", cmd.args[0], sym);
            }
        }
        else if(strcmp(cmd.cmd, "step") == 0 || strcmp(cmd.cmd, "s") == 0)
        {
            if(enable_mdscr_single_step(state))
            {
                break;
            }
            else
            {
                printf("error: single step already enabled\n");
            }
        }
        else if(strcmp(cmd.cmd, "cont") == 0 || strcmp(cmd.cmd, "c") == 0)
        {
            break;
        }
        else if(strcmp(cmd.cmd, "exit") == 0 || strcmp(cmd.cmd, "quit") == 0)
        {
            state->thread.__pc = (uint64_t)exit;
            state->thread.__x[0] = 1;
            break;
        }
        else if(strcmp(cmd.cmd, "help") == 0 || strcmp(cmd.cmd, "h") == 0)
        {
            printf("bt [depth]                  - backtrace (default 20 frames)\n"
                   "reg [name] [value]          - show/set registers\n"
                   "  reg                       - show all registers\n"
                   "  reg x0                    - show x0\n"
                   "  reg pc 0x1000             - set PC to 0x1000\n"
                   "break <slot> <addr>         - set hardware breakpoint\n"
                   "delete <slot>               - clear hardware breakpoint\n"
                   "x <addr> [count]            - examine memory\n"
                   "disas [addr|symbol] [count] - disassemble\n"
                   "  disas 0xff00ff00          - disassemble address 0xff00ff00\n"
                   "  disas 0xff00ff00 10       - disassemble 10 bytes from address 0xff00ff00\n"
                   "  disas main                - disassemble main symbol\n"
                   "cont / c                    - continue execution\n"
                   "exit / quit                 - exit program\n"
                   "help / h                    - show this help\n");
        }
        else
        {
            printf("[ndb] unrecognized command \"%s\" (try 'help')\n", cmd.cmd);
        }
        
        fflush(stdout);
    }
}

void signal_handler(int code)
{
    __builtin_trap();
}

const char *exceptionName(exception_type_t exception)
{
    switch(exception)
    {
        case EXC_BAD_ACCESS: return "EXC_BAD_ACCESS";
        case EXC_BAD_INSTRUCTION: return "EXC_BAD_INSTRUCTION";
        case EXC_ARITHMETIC: return "EXC_ARITHMETIC";
        case EXC_EMULATION: return "EXC_EMULATION";
        case EXC_SOFTWARE: return "EXC_SOFTWARE";
        case EXC_BREAKPOINT: return "EXC_BREAKPOINT";
        case EXC_SYSCALL: return "EXC_SYSCALL";
        case EXC_MACH_SYSCALL: return "EXC_MACH_SYSCALL";
        case EXC_RPC_ALERT: return "EXC_RPC_ALERT";
        case EXC_CRASH: return "EXC_CRASH";
        case EXC_RESOURCE: return "EXC_RESOURCE";
        case EXC_GUARD: return "EXC_GUARD";
        case EXC_CORPSE_NOTIFY: return "EXC_CORPSE_NOTIFY";
        default: return "EXC_UNKNOWN";
    }
}

kern_return_t mach_exception_self_server_handler(mach_port_t task,
                                                 mach_port_t thread,
                                                 exception_type_t exception,
                                                 mach_exception_data_type_t *code,
                                                 mach_msg_type_number_t codeCnt)
{
    /* preparing */
    kern_return_t kr = KERN_SUCCESS;
    thread_act_array_t cachedThreads = NULL;
    mach_msg_type_number_t cachedThreadCount = 0;
    
    /*
     * in case its our own task, then we need to carefully
     * suspend all threads except this one, to achieve
     * a safe task state.
     */
    if(task == mach_task_self_)
    {
        /* getting all threads */
        kr = task_threads(mach_task_self(), &cachedThreads, &cachedThreadCount);
        
        /* thanks to opa334 suspending them */
        if(kr == KERN_SUCCESS)
        {
            suspend_threads_except_for(cachedThreads, cachedThreadCount, mach_thread_self());
        }
    }
    else
    {
        /* usual procedure, suspend that task lol */
        task_suspend(task);
    }
    
    /* getting current thread state */
    struct arm64_thread_full_state *state = thread_save_state_arm64(thread);
    
    /*
     * in case single stepping is enabled,
     * which is only enabled for one instruction,
     * we basically know that it means someone meant
     * to over-step this instruction, means we skip it
     * automatically.
     */
    if(is_enabled_mdscr_single_step(state))
    {
        state->thread.__pc = get_next_pc(state);
        goto skip_debug_loop;
    }
    
    mach_msg_type_number_t index = 0;
    task_thread_index(task, thread, &index);
    
    /* printing out what happened */
    printf("[ndb] [%s] thread %d stopped at 0x%llx(%s)\n", exceptionName(exception), task_thread_index(task, thread, &index), state->thread.__pc, sym_at_address(state->thread.__pc));
    
    /* parsing exception */
    if(exception == EXC_BAD_ACCESS)
    {
        /* getting exception details */
        uint32_t esr = state->exception.__esr;
        uint32_t ec = (esr >> 26) & 0x3F;
        uint32_t iss = esr & 0x1FFFFFF;
        
        switch (ec) {
            case 0x20: /* instruction abort from lower EL */
            case 0x21: /* instruction abort from same EL */
                printf("execution failed at 0x%llx\n", state->exception.__far);
                printf("  (instruction fetch failed)\n");
                break;
                
            case 0x24: /* data abort from lower EL */
            case 0x25: /* data abort from same EL */
            {
                bool is_write = (iss >> 6) & 1;
                printf("%s failed at 0x%llx\n", is_write ? "writing" : "reading", state->exception.__far);
                
                /* decoding fault status */
                uint32_t dfsc = iss & 0x3F;
                printf("  fault status code: 0x%02x ", dfsc);
                switch(dfsc & 0x3C)
                {
                    case 0x04: printf("(translation fault)\n"); break;
                    case 0x08: printf("(access flag fault)\n"); break;
                    case 0x0C: printf("(permission fault)\n"); break;
                    default: printf("(other fault)\n"); break;
                }
                break;
            }
            default:
                printf("other exception class: 0x%02x\n", ec);
                break;
        }
    }
    
    /* invoking nyxian debugger(nbd) */
    debugger_loop(thread, state);
    
skip_debug_loop:
    
    /* resture thread state */
    thread_restore_state_arm64(thread, state);
    
    /* same game as before */
    if(task == mach_task_self_)
    {
        if(kr == KERN_SUCCESS)
        {
            resume_threads_except_for(cachedThreads, cachedThreadCount, mach_thread_self());
        }
    }
    else
    {
        task_resume(task);
    }
    
    return KERN_SUCCESS;
}

void* mach_exception_self_server(void *arg)
{
    // Our task is the target, the exception port as the receive side of the kernel exception messages, the mask is basically controlling to what our exception server reacts to
    task_t task = mach_task_self();
    mach_port_t exceptionPort = MACH_PORT_NULL;
    exception_mask_t  mask = EXC_MASK_BAD_ACCESS | EXC_MASK_BAD_INSTRUCTION | EXC_MASK_ARITHMETIC | EXC_MASK_SOFTWARE | EXC_MASK_BREAKPOINT | EXC_MASK_SYSCALL | EXC_MASK_CRASH;
    
    // Allocating mach port and setting it up with our process
    mach_port_allocate(task, MACH_PORT_RIGHT_RECEIVE, &exceptionPort);
    mach_port_insert_right(task, exceptionPort, exceptionPort, MACH_MSG_TYPE_MAKE_SEND);
    task_set_exception_ports(task, mask, exceptionPort, EXCEPTION_STATE_IDENTITY, ARM_THREAD_STATE64);
    
    // Thanks to microsoft, without you this wouldnt be possible and I wouldnt understand yet what to do. The request is send by the kernel to our mach port
    __Request__exception_raise_t *request = NULL;
    size_t request_size = round_page(sizeof(*request));
    kern_return_t kr;
    mach_msg_return_t mr;
    
    // Allocating the request structure to have a writing destination
    kr = vm_allocate(mach_task_self(), (vm_address_t *) &request, request_size, VM_FLAGS_ANYWHERE);
    if(kr != KERN_SUCCESS)
    {
        // Shouldn't happen ...
        fprintf(stderr, "Unexpected error in vm_allocate(): %x\n", kr);
        return NULL;
    }
    
    environment_syscall(SYS_HANDOFFEP, exceptionPort);
    
    while(1)
    {
        // Now requesting the message and waiting on a reply from the kernel.. happens on exception
        request->Head.msgh_local_port = exceptionPort;
        request->Head.msgh_size = (mach_msg_size_t)request_size;
        mr = mach_msg(&request->Head,
                      MACH_RCV_MSG | MACH_RCV_LARGE,
                      0,
                      request->Head.msgh_size,
                      exceptionPort,
                      MACH_MSG_TIMEOUT_NONE,
                      MACH_PORT_NULL);
        
        // Microsofts code to handle if the exception message send by the kernel is valid to process
        if(mr != MACH_MSG_SUCCESS && mr == MACH_RCV_TOO_LARGE)
        {
            // Determine the new size (before dropping the buffer)
            request_size = round_page(request->Head.msgh_size);
            
            // Drop the old receive buffer
            vm_deallocate(mach_task_self(), (vm_address_t) request, request_size);
            
            // Re-allocate a larger receive buffer
            kr = vm_allocate(mach_task_self(), (vm_address_t *) &request, request_size, VM_FLAGS_ANYWHERE);
            if(kr != KERN_SUCCESS)
            {
                // Shouldn't happen ...
                fprintf(stderr, "Unexpected error in vm_allocate(): 0x%x\n", kr);
                return NULL;
            }
           
            continue;
            
        }
        else if (mr != MACH_MSG_SUCCESS)
            exit(-1);
        
        // Sanity checks
        if (request->Head.msgh_size < sizeof(*request) || request_size - sizeof(*request) < (sizeof(mach_exception_data_type_t) * request->codeCnt))
            exit(-1);
        
        mach_exception_data_type_t *code64 = (mach_exception_data_type_t *) request->code;
        
        // The final exception handler
        kr = mach_exception_self_server_handler(request->task.name,
                                                request->thread.name,
                                                request->exception, code64,
                                                request->codeCnt);
        
        // The faulting thread will be stopped until the reply was send to the kernel
        __Reply__exception_raise_t reply;
        memset(&reply, 0, sizeof(reply));
        reply.Head.msgh_bits = MACH_MSGH_BITS(MACH_MSGH_BITS_REMOTE(request->Head.msgh_bits), 0);
        reply.Head.msgh_id = request->Head.msgh_id + 100;
        reply.Head.msgh_local_port = MACH_PORT_NULL;
        reply.Head.msgh_remote_port = request->Head.msgh_remote_port;
        reply.Head.msgh_size = sizeof(reply);
        reply.NDR = NDR_record;
        reply.RetCode = kr;
        mr = mach_msg(&reply.Head, MACH_SEND_MSG, reply.Head.msgh_size, 0, MACH_PORT_NULL, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
        if(mr != KERN_SUCCESS)
            exit(-1);
    }
}

void machServerInit(void)
{
    // Dispatching once cuz the mach server shall only be initilized once
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        // Setting each signal to be blocked, in order to make the threads stop on fault, in the past it just continued running
        sigset_t set;
        sigfillset(&set);
        sigdelset(&set, SIGKILL);
        sigdelset(&set, SIGSTOP);
        sigdelset(&set, SIGABRT);
        sigdelset(&set, SIGTERM);
        
        // Using sigprocmask because according to libc source pthread_sigmask is just sigprocmask
        sigprocmask(SIG_BLOCK, &set, NULL);
        
        // Its raised by stuff like malloc API symbols but doesnt matter so much... we raise the mach exception manually in our abort handler. the thread wont continue running as its literally raised by the abort() function that calls based on libc source raise(SIGABRT) which mean it directly jump to our handler.
        signal(SIGABRT, signal_handler);
        
        // Executing finally out mach exception server
        pthread_t serverThread;
        pthread_create(&serverThread,
                       NULL,
                       mach_exception_self_server,
                       NULL);
        
        // Detach thread to automatically release its resources when it returns, cuz we wont join it
        pthread_detach(serverThread);
    });
}
