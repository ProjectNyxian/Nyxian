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

#include <LindChain/ProcEnvironment/tfp.h>
#include <LindChain/litehook/litehook.h>
#include <LindChain/ProcEnvironment/Surface/proc/proc.h>
#include <LindChain/ProcEnvironment/syscall.h>
#include <LindChain/Debugger/MachServer.h>
#include <LindChain/ProcEnvironment/Utils/ktfp.h>
#include <mach/mach.h>

kern_return_t environment_task_for_pid(mach_port_name_t tp_in,
                                       pid_t pid,
                                       mach_port_name_t *tp_out)
{
    /* sanity check */
    if(tp_out == NULL)
    {
        return KERN_FAILURE;
    }
    
    int64_t ret = environment_syscall(SYS_gettask, pid, false, tp_out);
    
    if(ret == -1 ||
       *tp_out == MACH_PORT_NULL)
    {
        return KERN_FAILURE;
    }
    
    return KERN_SUCCESS;
}

DEFINE_HOOK(task_name_for_pid, kern_return_t, (mach_port_name_t tp_in,
                                               pid_t pid,
                                               mach_port_name_t *tp_out))
{
    /* sanity check */
    if(tp_out == NULL)
    {
        return KERN_FAILURE;
    }
    
    /*
     * boolean flag to true means that we only want
     * the name port.
     */
    int64_t ret = environment_syscall(SYS_gettask, pid, true, tp_out);
    
    if(ret == -1 ||
       *tp_out == MACH_PORT_NULL)
    {
        return KERN_FAILURE;
    }
    
    return KERN_SUCCESS;
}

/*
 Init
 */
void environment_tfp_init(void)
{
    /* sending our task port to the task port system */
    ktfp(KTFP_GUEST);
    
    /* hooking tfp api */
    litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, task_for_pid, environment_task_for_pid, NULL);
    DO_HOOK_GLOBAL(task_name_for_pid);
}
