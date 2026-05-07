/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 mach-port-t

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

#include <LindChain/ProcEnvironment/Surface/sys/compat/waittask.h>
#include <LindChain/ProcEnvironment/Surface/proc/proc.h>

typedef struct waittask_payload {
    task_t task;
    recv_buffer_t *buffer;
} waittask_payload_t;

bool waittask_proc_event_handler(kvobject_event_type_t type,
                                 uint64_t val,
                                 kvobject_event_t *event)
{
    waittask_payload_t *payload = (waittask_payload_t*)(event->ctx);
    
    switch(type)
    {
        case kvObjEventDeinit:
        case kvObjEventCustom1: /* task port available */
            errno = 0;
            send_reply(&(payload->buffer->header), 0, NULL, 0, true);
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
    pid_t pid = (pid_t)args[0];
    
    /* need process visibility */
    proc_visibility_t vis = get_proc_visibility(sys_proc_snapshot_);
    
    /* getting target requested for caller */
    ksurface_proc_t *target;
    kern_return_t ksr = proc_for_pid(pid, &target);
    if(ksr != KERN_SUCCESS)
    {
        sys_return_failure(ECHILD);
    }
    
    /* visibility check */
    kvo_rdlock(target);
    if(!can_see_process(sys_proc_snapshot_, target, vis))
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
        sys_return_failure(ECHILD);  /* doesnt exist for the caller */
    }
    kvo_unlock(target);
    
    /* looking if state is already set */
    task_rdlock();
    if(target->task != MACH_PORT_NULL)
    {
        task_unlock();
        kvo_release(target);
        sys_return;
    }
    task_unlock();
    
    /* creating payload */
    waittask_payload_t *payload = malloc(sizeof(waittask_payload_t));
    
    if(payload == NULL)
    {
        kvo_release(target);
        sys_return_failure(ENOMEM);
    }
    
    kern_return_t kr = mach_port_mod_refs(mach_task_self(), sys_task_, MACH_PORT_RIGHT_SEND, 1);
    if(kr != KERN_SUCCESS)
    {
        goto out_again;
    }
    
    /* stuffing payload */
    payload->task = sys_task_;
    payload->buffer = *recv_buffer;
    
    /* register event */
    ksr = kvo_event_register(target, kvObjEventCustom1, waittask_proc_event_handler, payload, NULL);
    if(ksr != KERN_SUCCESS)
    {
        mach_port_deallocate(mach_task_self(), sys_task_);  /* drop the reference, created prior */
    out_again:
        free(payload);
        kvo_release(target);
        sys_return_failure(EAGAIN);
    }
    
    *recv_buffer = NULL;
    
    kvo_release(target);
    sys_return;
}
