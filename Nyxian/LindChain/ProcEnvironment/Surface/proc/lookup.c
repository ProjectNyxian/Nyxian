/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2025 - 2026 emexlab

 This file is part of Nyxian.

 Licensed under the emexLabs Public Source License, version 1.1
 (EPSL 1.1).

 Private use and modification are permitted under the license.
 Redistribution of source or binaries, modified or unmodified,
 requires prior written permission from emexLabs.

 External deployment is subject to the source-availability
 requirements and other conditions of the license.

 Provided "AS IS", without warranty, to the extent permitted by law.

 See LICENSE for the full license terms.
*/

#include <LindChain/ProcEnvironment/Surface/proc/lookup.h>
#include <LindChain/ProcEnvironment/Surface/proc/def.h>
#import <LindChain/ProcEnvironment/Surface/libkern/patch.h>
#include <assert.h>

kern_return_t proc_for_pid(pid_t pid,
                           ksurface_proc_t **proc)
{
    assert(proc != NULL);
    
    proc_table_rdlock();
    
    /* process lookup */
    ksurface_proc_t *found = radix_lookup(&(ksurface->proc_info.tree), pid);
    if(found == NULL)
    {
        proc_table_unlock();
        return KERN_NOT_FOUND;
    }
    
    /*
     * caller expects retained process object, so
     * attempting to retain it and if it doesnt work
     * returning with an error.
     */
    bool retained = kvo_retain(found);
    proc_table_unlock();
    if(!retained)
    {
        return KERN_FAILURE;
    }
    
    *proc = found;
    return KERN_SUCCESS;
}

kern_return_t proc_for_pid_with_pidv(pid_t pid,
                                     int pidv,
                                     ksurface_proc_t **proc)
{
    /* aquiring proc object */
    ksurface_proc_t *found = NULL;
    kern_return_t kr = proc_for_pid(pid, &found);
    if(kr != KERN_SUCCESS)
    {
        return kr;
    }
    
    /* perform pidv validation */
    kvo_rdlock(found);
    bool valid = (proc_getpidv(found) == pidv);
    kvo_unlock(found);
    if(!valid)
    {
        kvo_release(found);
        return KERN_NOT_FOUND;
    }
    
    *proc = found;
    return KERN_SUCCESS;
}

LIBKERN_DEFINE_PATCHABLE(kern_return_t, proc_task_for_proc, (ksurface_proc_t *proc,
                                                             task_special_port_t *flavour,
                                                             task_t *task))
{
    assert(proc != NULL && task != NULL && flavour != NULL);
    
    /*
     * whitelisting acquirable task special ports
     * by type, making sure we hand in a expected
     * type.
     */
    switch(*flavour)
    {
        case TASK_KERNEL_PORT:
        case TASK_NAME_PORT:
        case TASK_INSPECT_PORT:
        case TASK_READ_PORT:
            /* valid type */
            break;
        default:
            return KERN_INVALID_ARGUMENT;
    }
    
    /* temporary task port to not leak port value on failure */
    kvo_rdlock(proc);
    if(proc->task == MACH_PORT_NULL)
    {
        kvo_unlock(proc);
        return KERN_INVALID_TASK;
    }
    
    task_t tmp_task = proc->task;
    
    /*
     * validating ipc port type, making sure the type
     * matches supported types and handling them appropriate
     * to their type.
     */
    ipc_info_object_type_t ipc_port_type;
    kern_return_t kr = mach_port_kernel_object(mach_task_self(), tmp_task, &ipc_port_type, NULL);
    if(kr != KERN_SUCCESS)
    {
        /*
         * failed to lookup mach ipc port type
         * cannot validate type.
         */
        kvo_unlock(proc);
        return KERN_INVALID_NAME;
    }
    
    switch(ipc_port_type)
    {
        case IPC_OTYPE_TASK_CONTROL:    /* IKOT_TASK */
            /*
             * it's a task control port, so we can
             * export a task port of the flavour in
             * question.
             *
             * task_get_special_port() does create a
             * new mach port reference.
             *
             * this port type means the task behind
             * the port is a normal task ksurface
             * serves for.
             */
            kr = task_get_special_port(tmp_task, *flavour, &tmp_task);
            break;
        case IPC_OTYPE_TASK_NAME:       /* IKOT_TASK_NAME */
            /*
             * it's a task name port, so we can only
             * create a new reference of the port in
             * question.
             *
             * mach_port_mod_refs() increments the
             * reference count of the port.
             *
             * this port type means the task behind
             * the port is sensitive and shall be
             * protected, for example ksurface's
             * task port it self is usually a task
             * name port to protect ksurface from
             * attacks.
             */
            *flavour = TASK_NAME_PORT;
            kr = mach_port_mod_refs(mach_task_self(), tmp_task, MACH_PORT_RIGHT_SEND, 1);
            break;
        default:
            /*
             * illegal port type, this shall not
             * happen, but in-case it does we
             * just return a error, otherwise this
             * becomes a attack vector for
             * system(ksurface) termination.
             */
            kr = KERN_INVALID_RIGHT;
            break;
    }
    kvo_unlock(proc);
    
    /*
     * should have worked, may not work due to some
     * condition, so it is way better guarding for
     * that condition.
     */
    if(kr != KERN_SUCCESS)
    {
        return KERN_FAILURE;
    }
    
    /*
     * exporting task port, you never export the
     * task port if the return value is not
     * SURFACE_SUCCESS, if you do it and try to
     * pull request that junk to Nyxians codebase
     * this will be your last pull request to Nyxians
     * codebase, because this is part of a important
     * contract with the syscall server for example.
     */
    *task = tmp_task;
    
    return KERN_SUCCESS;
}

kern_return_t proc_task_for_pid(pid_t pid,
                                task_special_port_t *flavour,
                                task_t *task)
{
    /* aquiring proc object */
    ksurface_proc_t *found = NULL;
    kern_return_t kr = proc_for_pid(pid, &found);
    if(kr != KERN_SUCCESS)
    {
        return kr;
    }
    
    kr = proc_task_for_proc(found, flavour, task);
    kvo_release(found);
    return kr;
}

kern_return_t proc_parent_for_proc(ksurface_proc_t *child,
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
    bool success = !(strong_parent == NULL || !kvo_retain(strong_parent));
    pthread_mutex_unlock(&(child->children.mutex));
    if(success)
    {
        *parent = strong_parent;
        return KERN_SUCCESS;
    }
    
    return KERN_NO_ACCESS;
}

kern_return_t proc_exists_for_pid(pid_t pid)
{
    proc_table_rdlock();
    ksurface_proc_t *proc_entry = radix_lookup(&(ksurface->proc_info.tree), pid);
    proc_table_unlock();
    return proc_entry == NULL ? KERN_NOT_FOUND : KERN_SUCCESS;
}
