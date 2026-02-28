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

#import <LindChain/ProcEnvironment/Utils/ktfp.h>
#import <LindChain/ProcEnvironment/Utils/klog.h>
#import <LindChain/ProcEnvironment/syscall.h>

#if !JAILBREAK_ENV

task_t ktfp(obtain_token_t token)
{
    kern_return_t kr;
    
    /* the port either for listening or handoff */
    mach_port_t exceptionPort = MACH_PORT_NULL;
    
    if(token == KTFP_GUEST)
    {
        /* preparing for handoff */
        mach_port_options_t opt = {
            .flags =  MPO_PORT | MPO_INSERT_SEND_RIGHT
        };
        
        /* constructing port */
        kr = mach_port_construct(mach_task_self(), &opt, 0, &exceptionPort);
        
        /* sanity check */
        if(kr != KERN_SUCCESS)
        {
            return MACH_PORT_NULL;
        }
        
        /* setting it as exception port */
        kr = task_set_exception_ports(mach_task_self(), EXC_MASK_BREAKPOINT, exceptionPort, EXCEPTION_DEFAULT, ARM_THREAD_STATE64);
        
        /* sanity check */
        if(kr != KERN_SUCCESS)
        {
            goto out_dealloc;
        }
        
        /* handing off receive right to host environment */
        environment_syscall(SYS_handoffep, exceptionPort);
        
        /*
         * this trap will be sent by the iOS kernel it self
         * to the exception port of nyxian.
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
    
    /* will carry request buffer */
    __Request__exception_raise_t *request = NULL;
    size_t request_size = round_page(sizeof(*request));
    mach_msg_return_t mr;
    
    /* allocating request buffer via mach, page alligned */
    kr = vm_allocate(mach_task_self(), (vm_address_t *) &request, request_size, VM_FLAGS_ANYWHERE);
    if(kr != KERN_SUCCESS)
    {
        klog_log(@"ktfp", @"allocating request buffer failed: %s", mach_error_string(kr));
        goto out_destroy_recv;
    }
    
    // Now requesting the message and waiting on a reply from the kernel.. happens on exception
    request->Head.msgh_local_port = exceptionPort;
    request->Head.msgh_size = (mach_msg_size_t)request_size;
    mr = mach_msg(&(request->Head), MACH_RCV_MSG | MACH_RCV_LARGE | MACH_RCV_TIMEOUT, 0, request->Head.msgh_size, exceptionPort, 1000, MACH_PORT_NULL);
    
    if(mr == MACH_RCV_TIMED_OUT)
    {
        klog_log(@"ktfp", @"attempt on aquiring task port timed out");
        goto out_destroy_recv;
    }
    else if(mr != MACH_MSG_SUCCESS)
    {
        klog_log(@"ktfp", @"failed receiving task port");
        goto out_destroy_recv;
    }
    
    /* task port validation */
    ipc_info_object_type_t type;
    mach_vm_address_t address;
    kr = mach_port_kobject(mach_task_self(), request->task.name, &type, &address);
    
    if(kr != KERN_SUCCESS)
    {
        klog_log(@"ktfp", @"failed getting the kobject type");
        goto out_destroy_recv;
    }
    
    /* checking for ipc object type */
    if(type != IPC_OTYPE_TASK_CONTROL)  /* also known as IKOT_TASK.. aka kernel task port */
    {
        klog_log(@"ktfp", @"port %d holding ipc object with type %d is not a IKOT_TASK", request->task.name, type);
        goto out_destroy_recv;
    }
    
    /* now manipulate thread state */
    arm_thread_state64_t state;
    mach_msg_type_number_t count = ARM_THREAD_STATE64_COUNT;
    kr = thread_get_state(request->thread.name, ARM_THREAD_STATE64, (thread_state_t)&state, &count);
    
    if(kr != KERN_SUCCESS)
    {
        klog_log(@"ktfp", @"failed to get thread state");
        goto out_destroy_recv;
    }
    
    state.__pc += 4;
    
    kr = thread_set_state(request->thread.name, ARM_THREAD_STATE64, (thread_state_t)&state, count);
    
    if(kr != KERN_SUCCESS)
    {
        klog_log(@"ktfp", @"failed to restore thread state");
        goto out_destroy_recv;
    }
    
    task_t exportedTask = request->task.name;
    
    /* after replying the kernel will happily continue executing the task */
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
    {
        klog_log(@"ktfp", @"failed to reply back to guest");
        goto out_destroy_recv;
    }
    
    mach_port_mod_refs(mach_task_self(), exceptionPort, MACH_PORT_RIGHT_RECEIVE, -1);
    return exportedTask;

out_destroy_recv:
    mach_port_mod_refs(mach_task_self(), exceptionPort, MACH_PORT_RIGHT_RECEIVE, -1);
    return MACH_PORT_NULL;
}

#endif /* !JAILBREAK_ENV */
