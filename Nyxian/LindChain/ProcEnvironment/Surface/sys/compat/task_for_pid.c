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

#include <LindChain/ProcEnvironment/Surface/sys/compat/task_for_pid.h>
#include <LindChain/ProcEnvironment/Surface/proc/proc.h>
#include <LindChain/ProcEnvironment/Surface/proc/permit.h>

DEFINE_SYSCALL_HANDLER(task_for_pid)
{
    /* parse arguments */
    pid_t pid = (pid_t)args[0];
    bool name_only = (bool)args[1];
    
    /* getting the target process */
    ksurface_proc_t *target;
    kern_return_t ret = proc_for_pid(pid, &target);
    if(ret != KERN_SUCCESS)
    {
        sys_return_failure_with_errno(ESRCH);
    }
    
    /*
     * checks if target gives permissions to get the task port of it self
     * in the first place and if the process allows for it except if the
     * caller is a special process.
     */
    if(!proc_snapshot_primitive_over_proc_allowed(sys_proc_snapshot_, target, name_only ? kPEEntitlementFlagNone : kPEEntitlementFlagTaskForPid, name_only ? kPEEntitlementFlagNone : kPEEntitlementFlagGetTaskAllowed, err))
    {
        /*
         * in case it has system task ports primitive
         * it is granted anyways.
         */
        if(*err != ESRCH && /* making sure we can see the target */
           entitlement_got_entitlement(proc_getentitlements(sys_proc_snapshot_), kPEEntitlementFlagSystemTaskPorts | kPEEntitlementFlagTaskForPid | kPEEntitlementFlagPlatform))
        {
            sys_set_errno(0);
            goto skip_bsd_primitive_semantic_check;
        }
        
        kvo_release(target);
        sys_return_failure();
    }
    
skip_bsd_primitive_semantic_check:
    {
        /* getting task port of flavour */
        task_t exportTask = MACH_PORT_NULL;
        task_special_port_t flavour = name_only ? TASK_NAME_PORT : TASK_KERNEL_PORT;
        kern_return_t kr = proc_task_for_proc(target, &flavour, &exportTask);
        kvo_release(target);
        if(kr != KERN_SUCCESS)
        {
            sys_return_failure_with_errno(EACCES);
        }
        
        if(name_only && flavour != TASK_NAME_PORT)
        {
            mach_port_deallocate(mach_task_self(), exportTask);
            sys_return_failure_with_errno(EACCES);
        }
        
        /* allocating syscall payload, so we can export it to the syscall caller */
        kr = syscall_payload_create(NULL, sizeof(mach_port_t), (mach_vm_address_t*)out_ports);
        if(kr != KERN_SUCCESS)
        {
            mach_port_deallocate(mach_task_self(), exportTask);
            sys_return_failure_with_errno(ENOMEM);
        }
        
        sys_export_port(exportTask);    /* set task port send right to be send */
        sys_return;
    }
}
