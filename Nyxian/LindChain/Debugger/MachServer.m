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

#import <LindChain/Debugger/MachServer.h>
#import <Foundation/Foundation.h>
#include <pthread.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <mach/exc.h>
#include <mach/exception.h>
#include <mach/exception_types.h>
#include <mach/thread_state.h>
#import <LindChain/ProcEnvironment/syscall.h>
#include "litehook.h"
#include "Utils.h"
#include <termios.h>
#import <LindChain/ProcEnvironment/Utils/klog.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>

ksurface_return_t ndb_attach(pid_t pid)
{
    /* for now NOOP */
    return SURFACE_SUCCESS;
    
    /*
     * the same shitty solution used in posix_spawn
     * MARK: pls... create a new api for this shit
     */
    usleep(50000);
    
    /* getting the task port of the process */
    task_t task;
    ksurface_return_t ksr = proc_task_for_pid(pid, TASK_KERNEL_PORT, &task);
    
    if(ksr != SURFACE_SUCCESS)
    {
        return ksr;
    }
    
    /*
     * suspend task so we can itterate
     * all its threads and add the
     * mach_thread_create hook to each of
     * those.
     *
     * for the future... lol
     */
    kern_return_t kr = task_suspend(task);
    if(kr != KERN_SUCCESS)
    {
        goto out_failed;
    }
    
    /* crafting exception port */
    mach_port_t exceptionPort;
    
    mach_port_options_t opt = {
        .flags =  MPO_PORT | MPO_INSERT_SEND_RIGHT
    };
    
    kr = mach_port_construct(mach_task_self(), &opt, 0, &exceptionPort);
    if(kr != KERN_SUCCESS)
    {
        return MACH_PORT_NULL;
    }
    
    /* attaching exception port */
    kr = task_set_exception_ports(task, EXC_MASK_BREAKPOINT, exceptionPort, EXCEPTION_DEFAULT, ARM_THREAD_STATE64);
    if(kr != KERN_SUCCESS)
    {
        mach_port_deallocate(mach_task_self(), exceptionPort);
        mach_port_mod_refs(mach_task_self(), exceptionPort, MACH_PORT_RIGHT_RECEIVE, -1);
        goto out_failed;
    }
    
    /*
     * resuming task so everything can continue
     * working as if it was the most normal thing
     * on planet earth ^^
     */
    kr = task_resume(task);
    if(kr != KERN_SUCCESS)
    {
        goto out_failed;
    }
    
    mach_port_deallocate(mach_task_self(), task);
    return SURFACE_SUCCESS;
    
out_failed:
    mach_port_deallocate(mach_task_self(), task);
    return SURFACE_FAILED;
}
