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
#import <LindChain/ProcEnvironment/panic.h>

ksurface_return_t proc_for_pid(pid_t pid,
                               ksurface_proc_t **proc)
{
    assert(proc != NULL);
    
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
    assert(proc != NULL && task != NULL);
    
    /* view note in SYS_gettask */
    task_rdlock();
    
    if(proc->task == MACH_PORT_NULL)
    {
        task_unlock();
        return SURFACE_FAILED;
    }
    
    /* temporary task port to not leak port value on failure */
    task_t tmp_task = proc->task;
    
    /*
     * validating ipc port type making sure the type
     * matches supported types and handling them appropriate
     * to their type.
     */
    ipc_info_object_type_t ipc_port_type;
    mach_vm_address_t placeholder_address;
    kern_return_t kr = mach_port_kobject(mach_task_self(), tmp_task, &ipc_port_type, &placeholder_address);
    
    if(kr != KERN_SUCCESS)
    {
        task_unlock();
        return SURFACE_FAILED;
    }
    
    if(ipc_port_type == IPC_OTYPE_TASK_CONTROL)
    {
        /*
         * its control task port, so we can
         * export a task port of the flavourt in
         * question.
         *
         * task_get_special_port() does create a
         * new mach port reference.
         */
        kr = task_get_special_port(tmp_task, flavour, &tmp_task);
    }
    else if(ipc_port_type == IPC_OTYPE_TASK_NAME)
    {
        /*
         * its name task port, so we can
         * just create a new reference of the name.
         * its a task name, because the kernel decided
         * that only a task name shall be exported, prior.
         */
        kr = mach_port_mod_refs(mach_task_self(), tmp_task, MACH_PORT_RIGHT_SEND, 1);
    }
    else
    {
        /* shall never happen, invalid type */
        environment_panic();
    }
    
    task_unlock();
    
    if(kr != KERN_SUCCESS)
    {
        return SURFACE_FAILED;
    }
    
    /* exporting task port */
    *task = tmp_task;
    
    return SURFACE_SUCCESS;
}
