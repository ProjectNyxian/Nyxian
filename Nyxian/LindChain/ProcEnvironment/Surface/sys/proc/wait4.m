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

#import <LindChain/ProcEnvironment/Surface/sys/proc/wait4.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/Surface/proc/list.h>
#import <LindChain/Multitask/ProcessManager/LDEProcessManager.h>

typedef struct wait4_payload {
    userspace_pointer_t status_ptr;
    userspace_pointer_t rusage_ptr;
    int options;
    task_t task;
    recv_buffer_t *buffer;
} wait4_payload_t;

bool wait4_proc_event_handler(kvobject_event_type_t type,
                              uint8_t val,
                              kvobject_event_t *event)
{
    ksurface_proc_t *proc = (ksurface_proc_t*)(event->owner);
    wait4_payload_t *payload = (wait4_payload_t*)(event->ctx);
    
    kvo_wrlock(proc);
    
    switch(type)
    {
        case kvObjEventCustom0: /* state change happened */
            
            /* looking if state change already happened */
            if((((payload->options & WSTOPPED) == WSTOPPED) && WIFSTOPPED(proc->nyx.p_status)) ||
               (((payload->options & WCONTINUED) == WCONTINUED) && WIFCONTINUED(proc->nyx.p_status)))
            {
                /* set to none, so incase it was
                 * stopped it wont fire again without
                 * another state change, cuz the state
                 * change was collected.
                 */
                kvo_unlock(proc);
                goto out_trigger_unregister;
            }
            else if(proc->bsd.kp_proc.p_stat == SZOMB)
            {
                /* process has already exited, reap it */
                kvo_unlock(proc);
                proc_reap(proc);
                goto out_trigger_unregister;
            }
            
            break;
        case kvObjEventDeinit:  /* exited */
        {
            goto out_trigger_unregister;
        }
        case kvObjEventUnregister:
            mach_port_deallocate(mach_task_self(), payload->task);
            free(payload);
            kvo_unlock(proc);
            return true;
        default:
            break;
    }
    
    kvo_unlock(proc);
    return false;

out_trigger_unregister:
    mach_syscall_copy_out(payload->task, sizeof(int), &(proc->nyx.p_status), payload->status_ptr);
    proc->nyx.p_status = 0;
    kvo_unlock(proc);
    send_reply(&(payload->buffer->header), 0, NULL, 0, 0, true);
    return true;
}

DEFINE_SYSCALL_HANDLER(wait4)
{    
    /* prepare arguments */
    pid_t pid = (pid_t)args[0];
    int options = (int)args[2];
    
    /* need process visibility */
    proc_visibility_t vis = get_proc_visibility(sys_proc_snapshot_);
    
    /* getting target requested for caller */
    ksurface_proc_t *target;
    ksurface_return_t ksr = proc_for_pid(pid, &target);
    
    if(ksr != SURFACE_SUCCESS)
    {
        sys_return_failure(ECHILD);
    }
    
    kvo_wrlock(target);
    
    /* visibility check */
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
    if(proc_getppid(target) != proc_getpid(proc_snapshot))
    {
    out_nochild:
        kvo_unlock(target);
        kvo_release(target);
        sys_return_failure(ECHILD);  /* doesnt exist for the caller */
    }
    
    /* looking if state change already happened */
    if((((options & WSTOPPED) == WSTOPPED) && WIFSTOPPED(target->nyx.p_status)) ||
       (((options & WCONTINUED) == WCONTINUED) && WIFCONTINUED(target->nyx.p_status)))
    {
        /* set to none, so incase it was
         * stopped it wont fire again without
         * another state change, cuz the state
         * change was collected.
         */
        goto out_report;
    }
    else if(target->bsd.kp_proc.p_stat == SZOMB)
    {
        /* process has already exited, reap it */
        proc_reap(target);
        
    out_report:
        mach_syscall_copy_out(sys_task_, sizeof(int), &(target->nyx.p_status), (userspace_pointer_t)args[1]);
        target->nyx.p_status = 0;
        kvo_unlock(target);
        kvo_release(target);
        sys_return;
    }
    
    /* creating payload */
    wait4_payload_t *payload = malloc(sizeof(wait4_payload_t));
    
    if(payload == NULL)
    {
        kvo_unlock(target);
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
    payload->status_ptr = (userspace_pointer_t)args[1];
    payload->rusage_ptr = (userspace_pointer_t)args[3];
    payload->options = options;
    payload->buffer = recv_buffer;
    
    /* register event */
    ksr = kvo_event_register(target, kvObjEventCustom0, wait4_proc_event_handler, payload, NULL);
    if(ksr != SURFACE_SUCCESS)
    {
        mach_port_deallocate(mach_task_self(), sys_task_);  /* drop the reference, created prior */
    out_again:
        free(payload);
        kvo_unlock(target);
        kvo_release(target);
        sys_return_failure(EAGAIN);
    }
    
    *reply = false;
    
    kvo_unlock(target);
    kvo_release(target);
    sys_return;
}
