/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2025 - 2026 emexlab

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

#include <LindChain/ProcEnvironment/Surface/sys/compat/waittask.h>
#include <LindChain/ProcEnvironment/Surface/proc/proc.h>

typedef struct waittask_payload {
    task_t task;
    recv_buffer_t *buffer;
} waittask_payload_t;

bool waittask_proc_event_handler(uint32_t type,
                                 uint64_t val,
                                 kvobject_event_t *event)
{
    waittask_payload_t *payload = (waittask_payload_t*)(event->ctx);
    
    switch(type)
    {
        case kvObjEventDeinit:
        case kProcEventTypeWaitTask:    /* task port available */
            errno = 0;
            syscall_send_reply(&(payload->buffer->header), 0, NULL, 0, true, 0);
            return true;
        case kvObjEventUnregister:
            mach_port_mod_refs(mach_task_self(), payload->task, MACH_PORT_RIGHT_SEND, -1);
            free(payload);
            return true;
        default:
            break;
    }
    
    return false;
}

DEFINE_SYSCALL_HANDLER(waittask)
{
    /* prepare arguments */
    pid_t u_pid = (pid_t)args[0];
    
    /* getting target requested for caller */
    ksurface_proc_t *target;
    kern_return_t kr = proc_for_pid(u_pid, &target);
    if(kr != KERN_SUCCESS)
    {
        sys_return_failure_with_errno(ECHILD);
    }
    
    /* visibility check */
    kvo_rdlock(target);
    proc_visibility_t vis = proc_get_proc_visibility(sys_proc_snapshot_);
    if(!proc_can_see_proc(sys_proc_snapshot_, target, vis))
    {
        goto out_nochild;
    }
    
    /*
     * parentship check, on UNIX its a standard
     * semantic, that you cannot wait on processes
     * that arent your children. so, we have to
     * check if it is a child process.
     */
    if(proc_getppid(target) != proc_getpid(sys_proc_snapshot_))
    {
    out_nochild:
        kvo_unlock(target);
        kvo_release(target);
        sys_return_failure_with_errno(ECHILD);  /* doesnt exist for the caller */
    }
    kvo_unlock(target);
    
    /* looking if task is already there (cuz the caller wants to wait till that is the case) */
    if(target->task != MACH_PORT_NULL)
    {
        kvo_release(target);
        sys_return;
    }
    
    /* creating payload */
    waittask_payload_t *payload = malloc(sizeof(waittask_payload_t));
    if(payload == NULL)
    {
        kvo_release(target);
        sys_return_failure_with_errno(ENOMEM);
    }
    
    kr = mach_port_mod_refs(mach_task_self(), sys_task_, MACH_PORT_RIGHT_SEND, 1);
    if(kr != KERN_SUCCESS)
    {
        goto out_again;
    }
    
    /* stuffing payload */
    payload->task = sys_task_;
    payload->buffer = *recv_buffer;
    
    /* register event */
    kr = kvo_event_register(target, kProcEventTypeWaitTask, waittask_proc_event_handler, payload, NULL);
    if(kr != KERN_SUCCESS)
    {
        mach_port_deallocate(mach_task_self(), sys_task_);  /* drop the reference, created prior */
    out_again:
        free(payload);
        kvo_release(target);
        sys_return_failure_with_errno(EAGAIN);
    }
    
    *recv_buffer = NULL;
    
    kvo_release(target);
    sys_return;
}
