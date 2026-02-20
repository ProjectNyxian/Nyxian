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

#import <LindChain/ProcEnvironment/Surface/proc/lookup.h>
#import <LindChain/ProcEnvironment/Surface/proc/def.h>
#import <LindChain/ProcEnvironment/tfp.h>

ksurface_return_t proc_for_pid(pid_t pid,
                               ksurface_proc_t **proc)
{
    /* sanity check */
    if(proc == NULL)
    {
        return SURFACE_NULLPTR;
    }
    
    /* process lookup */
    proc_table_rdlock();
    *proc = radix_lookup(&(ksurface->proc_info.tree), pid);
    proc_table_unlock();
    
    /*
     * caller expects retained process object, so
     * attempting to retain it and if it doesnt work
     * returning with an error.
     */
    if(*proc == NULL ||
       !kvo_retain(*proc))
    {
        return SURFACE_RETAIN_FAILED;
    }
    
    return SURFACE_SUCCESS;
}

ksurface_return_t task_for_proc(ksurface_proc_t *proc,
                                task_flavor_t flavour,
                                task_t *task)
{
    /* sanity check */
    if(proc == NULL &&
       task == NULL)
    {
        return SURFACE_NULLPTR;
    }
    
    /* process retention */
    if(!kvo_retain(proc))
    {
        return SURFACE_RETAIN_FAILED;
    }
    
    /* sanity check */
    if(proc->kproc.task == MACH_PORT_NULL)
    {
        kvo_release(proc);
        return SURFACE_FAILED;
    }
    
    /* view note in SYS_gettask */
    task_rdlock();
    
    *task = proc->kproc.task;
    
    /* getting flavour */
    if(environment_supports_full_tfp())
    {
        kern_return_t kr = task_get_special_port(*task, flavour, task);
        
        if(kr != KERN_SUCCESS)
        {
            task_unlock();
            kvo_release(proc);
            return SURFACE_FAILED;
        }
    }
    
    task_unlock();
    kvo_release(proc);
    return SURFACE_SUCCESS;
}
