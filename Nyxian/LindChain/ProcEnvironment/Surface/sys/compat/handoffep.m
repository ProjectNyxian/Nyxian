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

#import <LindChain/ProcEnvironment/Surface/sys/compat/handoffep.h>
#import <LindChain/ProcEnvironment/Surface/proc/def.h>
#import <LindChain/ProcEnvironment/Surface/proc/copy.h>
#import <LindChain/ProcEnvironment/Utils/klog.h>
#import <LindChain/Debugger/MachServer.h>
#import <pthread.h>

typedef struct {
    mach_port_t ep;         /* exception port */
    ksurface_proc_t *proc;  /* kernel surface process reference */
} khandoffep_t;

void *dothework(void *work)
{
    khandoffep_t *hep = (khandoffep_t*)work;
    
    task_t task = obtainTaskPortWithExceptionRecvRight(hep->ep);
    klog_log(@"handoffep:helper", @"got task kernel port right: %d", task);
    
    if(!kvo_retain(hep->proc))
    {
        mach_port_deallocate(mach_task_self(), task);
    }
    
    task_wrlock();
    
    hep->proc->kproc.task = task;
    
    task_unlock();
    kvo_release(hep->proc);
    
    free(work);
    return NULL;
}

DEFINE_SYSCALL_HANDLER(handoffep)
{
    /* syscall header */
    sys_name("SYS_handoffep");
    
    /* checking recv input port */
    if(in_recv == MACH_PORT_NULL)
    {
        sys_return_failure(EINVAL);
    }
    else
    {
        klog_log(@"handoffep", @"got exception receive port: %d", in_recv);
        
        khandoffep_t *hep = malloc(sizeof(mach_port_t));
        hep->ep = in_recv;
        hep->proc = sys_proc_copy_->proc;
        
        pthread_t thread;
        pthread_create(&thread, NULL, dothework, hep);
        pthread_detach(thread);
    }
    
    sys_return;
}
