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

kern_return_t environment_task_for_pid(mach_port_name_t tp_in,
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
    
    /* extracting task port */
    environment_tfp_extract_transfer_port(tp_out);
    
    /* return it */
    return KERN_SUCCESS;
}

bool environment_supports_full_tfp(void)
{
    /*
     * apple made it possible to transfer task ports on iOS 26.0, but
     * the method currently used doesnt work on iOS 26.1 so I guess
     * they reverted the change back.
     *
     * it works cause apple messed up to guard receive task ports
     * with MPG_IMMOVABLE_RECEIVE which is what makes task ports
     * unsendable on older and newer iOS than iOS 26.0. Another
     * option would be that apple tightened the send right of the
     * task port prior and post iOS 26.0. I also wanna say that
     * this still works on some iOS 26.1 Beta versions, got patched
     * in iOS 26.0 Beta 2 or 3.
     *
     * very saf tho, would have loved to see more of this.
     */
    struct utsname systemInfo;
    uname(&systemInfo);
    return strncmp(systemInfo.release, "25.0", 4) == 0;
}

mach_port_t environment_tfp_create_transfer_port(task_t task)
{
    if(environment_supports_full_tfp())
    {
        return task;
    }
    
    /* partially very narrow access */
    kern_return_t kr = task_create_identity_token(mach_task_self(), &task);
    
    if(kr != KERN_SUCCESS)
    {
        return MACH_PORT_NULL;
    }
    
    return task;
}

void environment_tfp_extract_transfer_port(mach_port_t *tport)
{
    if(environment_supports_full_tfp())
    {
        return;
    }
    
    task_id_token_t token = *tport;
    
    kern_return_t kr = task_identity_token_get_task_port(token, TASK_FLAVOR_NAME, tport);
    
    if(kr != KERN_SUCCESS)
    {
        *tport = MACH_PORT_NULL;
    }
    
    mach_port_deallocate(mach_task_self(), token);
}

/*
 Init
 */
void environment_tfp_init(void)
{
    if(environment_is_role(EnvironmentRoleGuest))
    {
        /* sending our task port to the task port system */
        environment_syscall(SYS_SENDTASK, environment_tfp_create_transfer_port(mach_task_self()));
        
        /* hooking task_for_pid(3) */
        litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, task_for_pid, environment_task_for_pid, nil);
    }
}
