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

#import <LindChain/ProcEnvironment/Surface/sys/compat/waittask.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>

typedef struct waittask_payload {
    task_t task;
    recv_buffer_t *buffer;
} waittask_payload_t;

bool waittask_proc_event_handler(kvobject_event_type_t type,
                                 uint8_t val,
                                 kvobject_event_t *event)
{
    if(type == kvObjEventInvalidate)
    {
        return false;
    }
    
    waittask_payload_t *payload = (waittask_payload_t*)(event->ctx);
    
    switch(type)
    {
        case kvObjEventDeinit:
        case kvObjEventCustom2: /* task port available */
            send_reply(&(payload->buffer->header), 0, NULL, 0, 0, true);
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
    
    /* checking if process is visible */
    proc_visibility_t vis = get_proc_visibility(sys_proc_snapshot_);
    
    /* get process reference to target */
    ksurface_proc_t *target;
    ksurface_return_t ksr = proc_for_pid(pid, &target);
    
    if(ksr != SURFACE_SUCCESS)
    {
        sys_return_failure(EINVAL);
    }
    
    /* perms check */
    if(!can_see_process(sys_proc_snapshot_, target, vis))
    {
        kvo_release(target);
        sys_return_failure(EINVAL);
    }
    
    /* creating payload */
    waittask_payload_t *payload = malloc(sizeof(waittask_payload_t));
    
    if(payload == NULL)
    {
        kvo_release(target);
        sys_return_failure(ENOMEM);
    }
    
    /* stuffing payload */
    payload->task = sys_task_;
    payload->buffer = recv_buffer;
    
    task_rdlock();
    
    /* looking if state is already set */
    if(target->task != MACH_PORT_NULL)
    {
        free(payload);
        kvo_release(target);
        sys_return;
    }
    
    task_unlock();
    
    mach_port_mod_refs(mach_task_self(), sys_task_, MACH_PORT_RIGHT_SEND, 1);
    
    /* register event */
    ksr = kvo_event_register(target, waittask_proc_event_handler, payload, NULL);
    if(ksr != SURFACE_SUCCESS)
    {
        free(payload);
        kvo_release(target);
        sys_return_failure(EAGAIN);
    }
    
    *reply = false;
    
    kvo_release(target);
    sys_return;
}
