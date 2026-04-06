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

#include <LindChain/ProcEnvironment/Surface/proc/lookup.h>
#include <LindChain/ProcEnvironment/Surface/proc/def.h>
#include <LindChain/ProcEnvironment/tfp.h>
#include <LindChain/ProcEnvironment/panic.h>
#include <assert.h>

ksurface_return_t proc_for_pid(pid_t pid,
                               ksurface_proc_t **proc)
{
    assert(proc != NULL);
    
    /* process lookup */
    proc_table_rdlock();
    *proc = radix_lookup(&(ksurface->proc_info.tree), pid);
    
    if(*proc == NULL)
    {
        proc_table_unlock();
        return SURFACE_UNAVAILABLE;
    }
    
    /*
     * caller expects retained process object, so
     * attempting to retain it and if it doesnt work
     * returning with an error.
     */
    if(!kvo_retain(*proc))
    {
        proc_table_unlock();
        return SURFACE_RETAIN_FAILED;
    }
    
    proc_table_unlock();
    return SURFACE_SUCCESS;
}

ksurface_return_t proc_task_for_proc(ksurface_proc_t *proc,
                                     task_special_port_t flavour,
                                     task_t *task)
{
    assert(proc != NULL && task != NULL);
    
    /*
     * whitelisting aquirable task special ports by proc,
     * making sure we hand in a expected type.
     */
    switch(flavour)
    {
        case TASK_KERNEL_PORT:
        case TASK_NAME_PORT:
        case TASK_INSPECT_PORT:
        case TASK_READ_PORT:
            break;
        default:
            return SURFACE_INVALID;
    }
    
    /*
     * claiming read onto task so no other process can
     * at the same time add their task port which could
     * lead to task port confusion, because of a tiny
     * window where a process could die while its
     * task port is requested and another process spawns
     * at the same time adding their task port which then
     * leads to this, permissions could be leaked by this
     * race by for example a root process handing off its
     * task port and it has the same port number as a port
     * that was unpriveleged before but not removed before.
     */
    task_rdlock();
    
    /* temporary task port to not leak port value on failure */
    task_t tmp_task = proc->task;
    
    /*
     * validating ipc port type, making sure the type
     * matches supported types and handling them appropriate
     * to their type.
     */
    ipc_info_object_type_t ipc_port_type;
    mach_vm_address_t placeholder_address;
    kern_return_t kr = mach_port_kobject(mach_task_self(), tmp_task, &ipc_port_type, &placeholder_address);
    if(kr != KERN_SUCCESS)
    {
        task_unlock();
        return SURFACE_LOOKUP_FAILED;
    }
    
    switch(ipc_port_type)
    {
        case IPC_OTYPE_TASK_CONTROL:    /* IKOT_TASK */
            /*
             * its control task port, so we can
             * export a task port of the flavour in
             * question.
             *
             * task_get_special_port() does create a
             * new mach port reference.
             */
            kr = task_get_special_port(tmp_task, flavour, &tmp_task);
            break;
        case IPC_OTYPE_TASK_NAME:       /* IKOT_TASK_NAME */
            /*
             * its name task port, so we can
             * just create a new reference of the name.
             * its a task name, because the ksurface decided
             * that only a task name shall be exported, prior.
             */
            kr = mach_port_mod_refs(mach_task_self(), tmp_task, MACH_PORT_RIGHT_SEND, 1);
            break;
        default:
            /* illegal port type */
            task_unlock();
            return SURFACE_LOOKUP_FAILED;
    }
    
    task_unlock();
    
    if(kr != KERN_SUCCESS)
    {
        return SURFACE_ACQUIRE_FAILED;
    }
    
    /*
     * exporting task port, you never export the
     * task port if the return value is not
     * SURFACE_SUCCESS, if you do it and try to
     * pull request that junk to Nyxians codebase
     * this will be your last pull request to Nyxians
     * codebase.
     */
    *task = tmp_task;
    
    return SURFACE_SUCCESS;
}

ksurface_return_t proc_task_for_pid(pid_t pid,
                                    task_special_port_t flavour,
                                    task_t *task)
{
    assert(task != NULL);
    
    /* looking up proc (creates reference) */
    ksurface_proc_t *proc = NULL;
    ksurface_return_t ksr = proc_for_pid(pid, &proc);
    
    if(ksr != SURFACE_SUCCESS)
    {
        return ksr;
    }
    
    /* looking up task port */
    ksr = proc_task_for_proc(proc, flavour, task);
    
    /* we dont need proc anymore */
    kvo_release(proc);
    
    return ksr;
}

ksurface_return_t proc_parent_for_proc(ksurface_proc_t *child,
                                       ksurface_proc_t **parent)
{
    assert(child != NULL && parent != NULL);
    
    /*
     * as the children structure holds
     * a reference to a parent already
     * we can safely retain it within
     * the mutex dance.
     */
    pthread_mutex_lock(&(child->children.mutex));
    ksurface_proc_t *strong_parent = child->children.parent;
    
    if(strong_parent == NULL ||
       !kvo_retain(strong_parent))
    {
        pthread_mutex_unlock(&(child->children.mutex));
        return SURFACE_UNAVAILABLE;
    }
    pthread_mutex_unlock(&(child->children.mutex));
    
    *parent = strong_parent;
    
    return SURFACE_SUCCESS;
}
