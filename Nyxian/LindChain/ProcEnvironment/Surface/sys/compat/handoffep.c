/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 cr4zyengineer
 Copyright (C) 2026 zipgod24

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

#include <LindChain/ProcEnvironment/Surface/sys/compat/handoffep.h>
#include <LindChain/ProcEnvironment/Surface/proc/def.h>
#include <LindChain/ProcEnvironment/Utils/klog.h>
#include <LindChain/ProcEnvironment/Utils/ktfp.h>
#include <pthread.h>

typedef struct {
    mach_port_t ep;         /* exception port */
    ksurface_proc_t *proc;  /* kernel surface process reference */
} khandoffep_t;

void *dothework(void *work)
{
    khandoffep_t *hep = (khandoffep_t*)work;
    
    task_t task = ktfp(hep->ep);
    
    if(task == MACH_PORT_NULL)
    {
        goto release_work;
    }
    
    if(!kvo_retain(hep->proc))
    {
        goto release_task;
    }
    
    task_wrlock();
    
    /* checking if pid matches up */
    pid_t pid;
    kern_return_t kr = pid_for_task(task, &pid);
    
    if(kr != KERN_SUCCESS ||
       pid != proc_getpid(hep->proc))
    {
        goto release_task;
    }
    
    hep->proc->task = task;
    
    task_unlock();
    
    kvo_event_trigger(hep->proc, kvObjEventCustom1, 0);
    kvo_release(hep->proc);
    free(work);
    return NULL;
    
release_task:
    mach_port_deallocate(mach_task_self(), task);
release_work:
    free(work);
    return NULL;
}

DEFINE_SYSCALL_HANDLER(handoffep)
{
    sys_need_in_ports(1, MACH_MSG_TYPE_MOVE_RECEIVE);
    task_rdlock();
    
    /* sanity check */
    if(sys_proc_->task != MACH_PORT_NULL)
    {
        /* task port already set */
        task_unlock();
        sys_return_failure(EPERM);
    }
    
    task_unlock();
    
    /* preparing ktfp */
    khandoffep_t *hep = malloc(sizeof(khandoffep_t));
    if(hep == NULL)
    {
        sys_return_failure(ENOMEM);
    }
    
    hep->ep = sys_in_ports[0];
    hep->proc = sys_proc_;
    
    /*
     * zero out receive in port
     * so destroying the mach message
     * wont release it.
     */
    sys_in_ports[0] = MACH_PORT_NULL;
    
    /* performing ktfp */
    pthread_t thread;
    pthread_create(&thread, NULL, dothework, hep);
    pthread_detach(thread);
    
    sys_return;
}
