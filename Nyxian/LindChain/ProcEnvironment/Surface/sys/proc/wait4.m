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
#import <LindChain/ProcEnvironment/Process/PEProcessManager.h>

typedef struct wait4_payload {
    userspace_pointer_t status_ptr;
    userspace_pointer_t rusage_ptr;
    int options;
    task_t task;
    recv_buffer_t *buffer;
    pid_t waitonpid;
} wait4_payload_t;

bool wait4_proc_event_handler(kvobject_event_type_t type,
                              uint64_t val,
                              kvobject_event_t *event)
{
    if(val == 0)
    {
        return false;
    }
    
    ksurface_proc_t *parent = (ksurface_proc_t*)(event->owner);
    wait4_payload_t *payload = (wait4_payload_t*)(event->ctx);
    ksurface_proc_t *child = (ksurface_proc_t*)(uintptr_t)val;
    
    pthread_mutex_lock(&(parent->children.mutex));
    kvo_wrlock(child);
    
    if(payload->waitonpid > 0 &&
       payload->waitonpid != proc_getpid(child))
    {
        kvo_unlock(child);
        pthread_mutex_unlock(&(parent->children.mutex));
        return false;
    }
    
    switch(type)
    {
        case kvObjEventCustom0: /* state change happened */
            
            /* looking if state change already happened */
            if((((payload->options & WSTOPPED) == WSTOPPED) && WIFSTOPPED(child->nyx.p_status)) ||
               (((payload->options & WCONTINUED) == WCONTINUED) && WIFCONTINUED(child->nyx.p_status)))
            {
                /* set to none, so incase it was
                 * stopped it wont fire again without
                 * another state change, cuz the state
                 * change was collected.
                 */
                goto out_trigger_unregister;
            }
            else if(child->bsd.kp_proc.p_stat == SZOMB)
            {
                /* process has already exited, reap it */
                pthread_mutex_unlock(&(parent->children.mutex));
                proc_reap(child);
                pthread_mutex_lock(&(parent->children.mutex));
                
                /* in-case it did stop but is now zombified */
                if(!WIFEXITED(child->nyx.p_status))
                {
                    child->nyx.p_status = W_EXITCODE(0, SIGKILL);
                }
                
                goto out_trigger_unregister;
            }
            
            break;
        case kvObjEventUnregister:
            kvo_unlock(child);
            pthread_mutex_unlock(&(parent->children.mutex));
            mach_port_deallocate(mach_task_self(), payload->task);
            free(payload);
            return true;
        default:
            break;
    }
    
    kvo_unlock(child);
    pthread_mutex_unlock(&(parent->children.mutex));
    return false;

out_trigger_unregister:
    mach_syscall_copy_out(payload->task, sizeof(int), &(child->nyx.p_status), payload->status_ptr);
    child->nyx.p_status = 0;
    send_reply(&(payload->buffer->header), proc_getpid(child), NULL, 0, 0, true);
    kvo_unlock(child);
    pthread_mutex_unlock(&(parent->children.mutex));
    return true;
}

DEFINE_SYSCALL_HANDLER(wait4)
{    
    /* prepare arguments */
    pid_t pid = (pid_t)args[0];
    int options = (int)args[2];
    
    /* need process visibility */
    proc_visibility_t vis = get_proc_visibility(sys_proc_snapshot_);
    
    pthread_mutex_lock(&(sys_proc_->children.mutex));
    for(uint64_t i = 0; i < sys_proc_->children.children_cnt; i++)
    {
        /*
         * getting strongly referenced process from array
         * it is strongly referenced, because of the mutex
         * and because of the reference contract done by
         * proc_fork(3)
         */
        ksurface_proc_t *proc = sys_proc_->children.children[i];
        
        if(pid < 0 || proc_getpid(proc) == pid)
        {
            kvo_rdlock(proc);
            
            /* visibility check */
            if(!can_see_process(sys_proc_snapshot_, proc, vis))
            {
                kvo_unlock(proc);
                continue;
            }
            
            /* need a new reference to safely use it */
            if(!kvo_retain(proc))
            {
                kvo_unlock(proc);
                continue;
            }
            
            /* looking if state change already happened */
            if((((options & WSTOPPED) == WSTOPPED) && WIFSTOPPED(proc->nyx.p_status)) ||
               (((options & WCONTINUED) == WCONTINUED) && WIFCONTINUED(proc->nyx.p_status)))
            {
                goto out_report;
            }
            else if(proc->bsd.kp_proc.p_stat == SZOMB)
            {
                /*
                 * process has already exited, reap it, but
                 * unlock the mutex, because proc_reap will
                 * lock it for it self
                 */
                pthread_mutex_unlock(&(sys_proc_->children.mutex));
                proc_reap(proc);
                pthread_mutex_lock(&(sys_proc_->children.mutex));
                
                /* in-case it did stop but is now zombified */
                if(!WIFEXITED(proc->nyx.p_status))
                {
                    proc->nyx.p_status = W_EXITCODE(0, SIGKILL);
                }
                
            out_report:
                mach_syscall_copy_out(sys_task_, sizeof(int), &(proc->nyx.p_status), (userspace_pointer_t)args[1]);
                
                /*
                 * set to none, so incase it was
                 * stopped it wont fire again without
                 * another state change, cuz the state
                 * change was collected.
                 */
                proc->nyx.p_status = 0;
                
                pid = proc_getpid(proc);
                kvo_unlock(proc);   /* unlock first! releasing it will cause entire process and lock to release */
                kvo_release(proc);
                pthread_mutex_unlock(&(sys_proc_->children.mutex));
                return pid;
            }
            
            kvo_unlock(proc);   /* unlock first! releasing it might cause entire process and lock to release */
            kvo_release(proc);
        }
        kvo_unlock(proc);
    }
    
    if((options & WNOHANG) == WNOHANG)
    {
        pthread_mutex_unlock(&(sys_proc_->children.mutex));
        sys_return;
    }
    
    /* creating payload */
    wait4_payload_t *payload = malloc(sizeof(wait4_payload_t));
    
    if(payload == NULL)
    {
        pthread_mutex_unlock(&(sys_proc_->children.mutex));
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
    payload->buffer = *recv_buffer;
    payload->waitonpid = pid;
    
    /* register event */
    ksurface_return_t ksr = kvo_event_register(sys_proc_, kvObjEventCustom0, wait4_proc_event_handler, payload, NULL);
    if(ksr != SURFACE_SUCCESS)
    {
        mach_port_deallocate(mach_task_self(), sys_task_);  /* drop the reference, created prior */
    out_again:
        pthread_mutex_unlock(&(sys_proc_->children.mutex));
        free(payload);
        sys_return_failure(EAGAIN);
    }
    
    pthread_mutex_unlock(&(sys_proc_->children.mutex));
    
    *recv_buffer = NULL;
    sys_return;
}
