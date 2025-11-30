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

#import <LindChain/ProcEnvironment/Surface/proc/reference.h>
#import <LindChain/ProcEnvironment/panic.h>
#import <LindChain/ProcEnvironment/Utils/klog.h>

bool proc_retain(ksurface_proc_t *proc)
{
    if(proc == NULL)
    {
        return false;
    }
    while(1)
    {
        int current = atomic_load(&proc->refcount);
        if(current <= 0 || atomic_load(&proc->dead))
        {
            //klog_log(@"proc:retain", @"retention failed, process %p already dead", proc);
            return false;
        }
        if(atomic_compare_exchange_weak(&proc->refcount, &current, current + 1))
        {
            if(atomic_load(&proc->dead))
            {
                //klog_log(@"proc:retain", @"retention failed, process %p already dead", proc);
                atomic_fetch_sub(&proc->refcount, 1);
                return false;
            }
            //klog_log(@"proc:retain", @"retained process %p to refcount %d", proc, current + 1);
            return true;
        }
    }
}

void proc_release(ksurface_proc_t *proc)
{
    if(proc == NULL) return;
    int old = atomic_fetch_sub(&proc->refcount, 1);
    //klog_log(@"proc:release", @"releasing process %p to refcount %d", proc, old - 1);
    if(old == 1)
    {
        klog_log(@"proc:release", @"freeing process %p", proc);
        pthread_mutex_destroy(&(proc->mutex));
        free(proc);
    }
    else if(old <= 0)
    {
        /* Released more than retained -> panic */
        environment_panic();
    }
}

