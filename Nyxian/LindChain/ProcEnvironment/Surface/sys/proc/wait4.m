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

#import <LindChain/ProcEnvironment/Surface/sys/proc/wait4.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/Surface/proc/list.h>
#import <LindChain/Multitask/ProcessManager/LDEProcessManager.h>

typedef struct wait4_payload {
    userspace_pointer_t status_ptr;
    userspace_pointer_t rusage_ptr;
    int options;
    task_t task;
    mach_msg_header_t header;
} wait4_payload_t;

bool wait4_proc_event_handler(kvobject_event_type_t type,
                              uint8_t val,
                              kvobject_event_t *event)
{
    ksurface_proc_t *proc = (ksurface_proc_t*)(event->owner);
    wait4_payload_t *payload = (wait4_payload_t*)(event->ctx);
    int ecode = 0;
    
    kvo_rdlock(proc);
    
    switch(type)
    {
        case kvObjEventCustom2:
            proc_exit((ksurface_proc_t*)(event->owner));
            return false;
        case kvObjEventDeinit:
            ecode = (proc->nyx.ret << 8) & 0xff00;
            goto out_byebye;
        case kvObjEventUnregister:
            mach_port_mod_refs(mach_task_self(), payload->task, MACH_PORT_RIGHT_SEND, -1);
            free(payload);
            return true;
        case kvObjEventCustom0:
            kvo_wrlock(((ksurface_proc_t*)event->owner));
            ((ksurface_proc_t*)event->owner)->nyx.p_stop_reported = 1;
            kvo_unlock(((ksurface_proc_t*)event->owner));
            if((payload->options & WSTOPPED) == WSTOPPED)
            {
                ecode = W_STOPCODE(SIGSTOP);
                goto out_byebye;
            }
            break;
        case kvObjEventCustom1:
            if((payload->options & WCONTINUED) == WCONTINUED)
            {
                ecode = W_STOPCODE(SIGCONT);
                goto out_byebye;
            }
            break;
        default:
            break;
    }
    
    kvo_unlock(proc);
    return false;

out_byebye:
    mach_syscall_copy_out(payload->task, sizeof(int), &ecode, payload->status_ptr);
    kvo_unlock(proc);
    send_reply(&(payload->header), 0, NULL, 0, 0);
    return true;
}

DEFINE_SYSCALL_HANDLER(wait4)
{    
    /* prepare arguments */
    pid_t pid = (pid_t)args[0];
    int options = (int)args[2];
    
    /* get process reference to target */
    ksurface_proc_t *target;
    ksurface_return_t ksr = proc_for_pid(pid, &target);
    
    if(ksr != SURFACE_SUCCESS)
    {
        sys_return_failure(EINVAL);
    }
    
    kvo_wrlock(target);
    
    /* checking if process is visible */
    proc_visibility_t vis = get_proc_visibility(sys_proc_snapshot_);
    
    /* perms check */
    if(!can_see_process(sys_proc_snapshot_, target, vis))
    {
        kvo_unlock(target);
        kvo_release(target);
        sys_return_failure(EINVAL);
    }
    
    /* creating payload */
    wait4_payload_t *payload = malloc(sizeof(wait4_payload_t));
    
    if(payload == NULL)
    {
        kvo_unlock(target);
        kvo_release(target);
        sys_return_failure(ENOMEM);
    }
    
    /* stuffing payload */
    payload->task = sys_task_;
    payload->status_ptr = (userspace_pointer_t)args[1];
    payload->rusage_ptr = (userspace_pointer_t)args[3];
    payload->options = options;
    payload->header = *request;
    
    /* check if one stopping is still in await to be received */
    if((options & WSTOPPED) == WSTOPPED)
    {
        if(target->bsd.kp_proc.p_stat == SSTOP &&
           target->nyx.p_stop_reported == 0)
        {
            target->nyx.p_stop_reported = 1;
            
            int ecode = W_STOPCODE(SIGSTOP);
            mach_syscall_copy_out(payload->task, sizeof(int), &ecode, payload->status_ptr);
            
            free(payload);
            kvo_unlock(target);
            kvo_release(target);
            sys_return;
        }
    }
    
    /* checking if zombified process is still in await */
    if(target->bsd.kp_proc.p_stat == SZOMB)
    {
        target->nyx.p_stop_reported = 1;
        
        int ecode = (target->nyx.ret << 8) & 0xff00;
        mach_syscall_copy_out(payload->task, sizeof(int), &ecode, payload->status_ptr);
        
        free(payload);
        kvo_unlock(target);
        kvo_release(target);
        sys_return;
    }
    
    mach_port_mod_refs(mach_task_self(), sys_task_, MACH_PORT_RIGHT_SEND, 1);
    
    /* register event */
    ksr = kvo_event_register(target, wait4_proc_event_handler, payload, NULL);
    if(ksr != SURFACE_SUCCESS)
    {
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
