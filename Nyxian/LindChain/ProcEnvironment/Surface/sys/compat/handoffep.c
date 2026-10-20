/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2025 - 2026 emexlab
 Copyright (C) 2026 zipgod24
 Copyright (C) 2026 semvis123

 This file is part of Nyxian.

 Licensed under the emexLabs Public Source License, version 1.1
 (EPSL 1.1).

 Private use and modification are permitted under the license.
 Redistribution of source or binaries, modified or unmodified,
 requires prior written permission from emexLabs.

 External deployment is subject to the source-availability
 requirements and other conditions of the license.

 Provided "AS IS", without warranty, to the extent permitted by law.

 See LICENSE for the full license terms.
*/

#include <LindChain/ProcEnvironment/Surface/libkern/klog.h>
#include <LindChain/ProcEnvironment/Surface/libkern/task_handoff.h>
#include <LindChain/ProcEnvironment/Surface/sys/compat/handoffep.h>
#include <LindChain/ProcEnvironment/Surface/proc/def.h>
#include <LindChain/ProcEnvironment/Surface/proc/spawn.h>

DEFINE_SYSCALL_HANDLER(handoffep)
{
    /* guest hands of a receive right of a exception port */
    sys_need_in_ports(1, MACH_MSG_TYPE_MOVE_RECEIVE);
    
    kvo_wrlock(sys_proc_);
    if(sys_proc_->task != MACH_PORT_NULL || sys_proc_->in_tfp_handoff)
    {
        /* task port's can only be initialized once per process lifecycle. */
        kvo_unlock(sys_proc_);
        sys_return_failure_with_errno(EPERM);
    }
    sys_proc_->in_tfp_handoff = true;
    kvo_unlock(sys_proc_);
    
    /* consuming the exception port so it won't be released by the send_reply symbol. */
    mach_port_t exceptionPort = sys_in_ports[0];
    sys_in_ports[0] = MACH_PORT_NULL;
    
    /*
     * reply to the guest process so that it can trigger the
     * pseudo exception using __builtin_trap.
     */
    syscall_send_reply((mach_msg_header_t*)*recv_buffer, 0, *out_ports, *out_ports_cnt, true, 0);
    *recv_buffer = NULL;    /* consuming the mach message header the syscall server uses so it won't attempt to reply. */
    
    task_t returnedTask;
    kern_return_t kr = task_handoff(exceptionPort, &returnedTask);
    mach_port_mod_refs(mach_task_self(), exceptionPort, MACH_PORT_RIGHT_RECEIVE, -1);
    if(kr != KERN_SUCCESS)
    {
        goto out_failure_kill;
    }
    
    /* validating the identity of the process behind the task port. */
    pid_t pid;
    kr = pid_for_task(returnedTask, &pid);
    if(kr != KERN_SUCCESS || pid != proc_getpid(sys_proc_snapshot_))
    {
        mach_port_deallocate(mach_task_self(), returnedTask);
        goto out_failure_kill;
    }
    
    kvo_wrlock(sys_proc_);
    sys_proc_->task = returnedTask;
    sys_proc_->in_tfp_handoff = false;
    kvo_unlock(sys_proc_);
    
    kvo_event_trigger(sys_proc_, kProcEventTypeWaitTask, 0);
    
    sys_return;
    
out_failure_kill:
    proc_kill(sys_proc_, SIGKILL);
    sys_return;
}
