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

#import <LindChain/ProcEnvironment/Utils/ktfp.h>
#import <LindChain/ProcEnvironment/Utils/klog.h>
#import <LindChain/ProcEnvironment/syscall.h>

#if !JAILBREAK_ENV

__attribute__((optnone))
task_t ktfp(obtain_token_t token)
{
    kern_return_t kr;
    
    /* the port either for listening or handoff */
    mach_port_t exceptionPort = MACH_PORT_NULL;
    
    if(token == KTFP_GUEST)
    {
        /*
         * constructing the exception port and
         * setting it to our task for the host,
         * to receive the IKOT_TASK of the guest
         * through it, therefore receiving full
         * power over the guest.
         */
        mach_port_options_t opt = {
            .flags =  MPO_PORT | MPO_INSERT_SEND_RIGHT
        };
        
        kr = mach_port_construct(mach_task_self(), &opt, 0, &exceptionPort);
        if(kr != KERN_SUCCESS)
        {
            return MACH_PORT_NULL;
        }
        
        kr = task_set_exception_ports(mach_task_self(), EXC_MASK_BREAKPOINT, exceptionPort, EXCEPTION_DEFAULT, ARM_THREAD_STATE64);
        if(kr != KERN_SUCCESS)
        {
            goto out_dealloc;
        }
        
        /* handing off receive right to host environment */
        environment_syscall(SYS_handoffep, exceptionPort);
        
        /*
         * this causes EXC_BREAKPOINT, which causes
         * a mach exception which will be sent to the
         * exception port which the host now holds the
         * receive right of meaning the host will
         * handle this pseudo exception.
         */
        __builtin_trap();
        
    out_dealloc:
        /*
         * task kernel port has been handoffed
         * since the exception port was moved to
         * the host process we just need one dealloc.
         */
        task_set_exception_ports(mach_task_self(), EXC_MASK_BAD_ACCESS, MACH_PORT_NULL, EXCEPTION_DEFAULT, THREAD_STATE_NONE);
        mach_port_deallocate(mach_task_self(), exceptionPort);
        return MACH_PORT_NULL;
    }
    else
    {
        /*
         * we are the host environment, we swallow the token
         * like ice cream ^^.
         */
        exceptionPort = token;
    }
    
    /* host handling of guest exception port */
    
    /* will carry request buffer */
    __Request__exception_raise_t request;
    size_t request_size = round_page(sizeof(request));
    mach_msg_return_t mr;
    
    /* receiving pseudo exception caused by guest */
    request.Head.msgh_local_port = exceptionPort;
    request.Head.msgh_size = (mach_msg_size_t)request_size;
    mr = mach_msg(&(request.Head), MACH_RCV_MSG | MACH_RCV_LARGE | MACH_RCV_TIMEOUT, 0, request.Head.msgh_size, exceptionPort, 1000, MACH_PORT_NULL);
    
    /* predefined variable */
    task_t exportedTask = MACH_PORT_NULL;
    
    /* handling timeout and other errors */
    if(mr != MACH_MSG_SUCCESS)
    {
        klog_log(@"ktfp", @"failed receiving task port");
        goto out_destroy_request;
    }
    
    /* task port validation */
    ipc_info_object_type_t type;
    mach_vm_address_t address;
    kr = mach_port_kobject(mach_task_self(), request.task.name, &type, &address);
    
    if(kr != KERN_SUCCESS)
    {
        klog_log(@"ktfp", @"failed getting the kobject type");
        goto out_destroy_request;
    }
    
    /* checking for ipc object type */
    if(type != IPC_OTYPE_TASK_CONTROL)  /* also known as IKOT_TASK.. aka kernel task port */
    {
        klog_log(@"ktfp", @"port %d holding ipc object with type %d is not a IKOT_TASK", request.task.name, type);
        goto out_destroy_request;
    }
    
    /*
     * now manipulate thread state of the thread
     * in the guest that has the exception, because
     * its a pseudo exception and if we wont skip
     * over the pseudo exception it will reexecute
     * it or crash.
     */
    arm_thread_state64_t state;
    mach_msg_type_number_t count = ARM_THREAD_STATE64_COUNT;
    kr = thread_get_state(request.thread.name, ARM_THREAD_STATE64, (thread_state_t)&state, &count);
    
    if(kr != KERN_SUCCESS)
    {
        klog_log(@"ktfp", @"failed to get thread state");
        goto out_destroy_request;
    }
    
    /* skipping over pseudo exception */
    state.__pc += 4;
    
    
    kr = thread_set_state(request.thread.name, ARM_THREAD_STATE64, (thread_state_t)&state, count);
    
    if(kr != KERN_SUCCESS)
    {
        klog_log(@"ktfp", @"failed to restore thread state");
        goto out_destroy_request;
    }
    
    kr = mach_port_mod_refs(mach_task_self(), request.task.name, MACH_PORT_RIGHT_SEND, 1);
    
    if(kr != KERN_SUCCESS)
    {
        klog_log(@"ktfp", @"failed to increment tsdk port send right");
        goto out_destroy_request;
    }
    
    exportedTask = request.task.name;
    
    /* after replying the kernel will happily continue executing the task */
    __Reply__exception_raise_t reply;
    memset(&reply, 0, sizeof(reply));
    reply.Head.msgh_bits = MACH_MSGH_BITS(MACH_MSGH_BITS_REMOTE(request.Head.msgh_bits), 0);
    reply.Head.msgh_id = request.Head.msgh_id + 100;
    reply.Head.msgh_local_port = MACH_PORT_NULL;
    reply.Head.msgh_remote_port = request.Head.msgh_remote_port;
    reply.Head.msgh_size = sizeof(reply);
    reply.NDR = NDR_record;
    reply.RetCode = kr;
    mr = mach_msg(&reply.Head, MACH_SEND_MSG, reply.Head.msgh_size, 0, MACH_PORT_NULL, MACH_MSG_TIMEOUT_NONE, MACH_PORT_NULL);
    
    if(mr != KERN_SUCCESS)
    {
        klog_log(@"ktfp", @"failed to reply back to guest");
    }
    
out_destroy_request:
    mach_msg_destroy(&(request.Head));
    mach_port_mod_refs(mach_task_self(), exceptionPort, MACH_PORT_RIGHT_RECEIVE, -1);
    return exportedTask;
}

#endif /* !JAILBREAK_ENV */
