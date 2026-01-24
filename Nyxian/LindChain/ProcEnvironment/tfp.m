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
#import <sys/utsname.h>

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
    /*
     * apple made it possible to transfer task ports on iOS 26.0, but
     * the method currently used doesnt work on iOS 26.1 so I guess
     * they reverted the change back.
     *
     * it works cause apple messed up to guard task ports with
     * MPG_IMMOVABLE_RECEIVE which makes the task port unsandable.
     */
    struct utsname systemInfo;
    uname(&systemInfo);
    return strncmp(systemInfo.release, "25.0", 4) == 0;
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
