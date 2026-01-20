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

#import <LindChain/ProcEnvironment/tfp.h>
#import <LindChain/ProcEnvironment/environment.h>
#import <LindChain/ProcEnvironment/proxy.h>
#import <LindChain/litehook/litehook.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <mach/mach.h>
#import <LindChain/ProcEnvironment/syscall.h>

kern_return_t environment_task_for_pid(mach_port_name_t tp_in,      /* tp_in is almost ignored because its obsolete for nyxians security model */
                                       pid_t pid,
                                       mach_port_name_t *tp_out)
{
    /* null pointer check */
    if(tp_out == NULL)
    {
        return KERN_FAILURE;
    }
    
    /* getting task port */
    task_t task = MACH_PORT_NULL;
    int64_t ret = environment_syscall(SYS_GETTASK, pid, tp_out);
    
    /* checking return */
    if(ret == -1)
    {
        return KERN_FAILURE;
    }
    
    /* return it */
    return KERN_SUCCESS;
}

bool environment_supports_tfp(void)
{
    // MARK: Apple seems to have implemented mach port transmission into iOS 26, as in iOS 18.7 RC and below it crashes but on iOS 26.0 RC it actually transmitts the task port
    if(@available(iOS 26.0, *))
    {
        if(@available(iOS 26.1, *))
        {
            // MARK: TaskPortGate is over?!
            return false;
        }
        return true;
    }
    return false;
}

/*
 Init
 */
void environment_tfp_init(void)
{
    if(environment_supports_tfp())
    {
        if(environment_is_role(EnvironmentRoleGuest))
        {
            /* sending our task port to the task port system */
            environment_syscall(SYS_SENDTASK, mach_task_self());
            
            /* hooking task_for_pid(3) */
            litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, task_for_pid, environment_task_for_pid, nil);
        }
    }
}
