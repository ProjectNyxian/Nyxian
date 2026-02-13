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

#import <LindChain/ProcEnvironment/Surface/proc/task.h>
#import <LindChain/ProcEnvironment/tfp.h>

ksurface_return_t task_for_proc(ksurface_proc_t *proc,
                                task_t *task)
{
    /* sanity check */
    if(proc == NULL &&
       task == NULL)
    {
        return SURFACE_NULLPTR;
    }
    
    if(!kvo_retain(proc))
    {
        return SURFACE_FAILED;
    }
    
    if(proc->kproc.task != MACH_PORT_NULL)
    {
        kvo_release(proc);
        return SURFACE_FAILED;
    }
    
    task_rdlock();
    
    if(!environment_supports_full_tfp())
    {
        kern_return_t kr = mach_port_mod_refs(mach_task_self(), proc->kproc.task, MACH_PORT_RIGHT_SEND, 1);
        if(kr != KERN_SUCCESS)
        {
            task_unlock();
            kvo_release(proc);
            return SURFACE_FAILED;
        }
    }
    
    *task = proc->kproc.task;
    
    task_unlock();
    kvo_release(proc);
    return SURFACE_SUCCESS;
}
