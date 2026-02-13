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
    int64_t ret = environment_syscall(SYS_gettask, pid, tp_out);
    
    /* checking return */
    if(ret == -1)
    {
        return KERN_FAILURE;
    }
    
    /* extracting task port */
    environment_tfp_extract_transfer_port(tp_out);
    
    if(*tp_out == MACH_PORT_NULL)
    {
        return KERN_FAILURE;
    }
    
    /* return it */
    return KERN_SUCCESS;
}

DEFINE_HOOK(task_name_for_pid, kern_return_t, (mach_port_name_t tp_in,
                                               pid_t pid,
                                               mach_port_name_t *tp_out))
{
    return environment_task_for_pid(tp_in, pid, tp_out);
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
     * in iOS 26.1 Beta 2 or 3.
     *
     * very sad tho, but nice that on other versions we got tnfp.
     */
    
    static bool isSupported = false;
    
    /*
     * only checking once for support, kernel version wont change
     * while nyxian runs obviously.
     */
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        struct utsname systemInfo;
        uname(&systemInfo);
        isSupported = strncmp(systemInfo.release, "25.0", 4) == 0;
    });
    
    return isSupported;
}

mach_port_t environment_tfp_create_transfer_port(task_t task)
{
    /*
     * when full tfp fix is supported that means that the task
     * port it self can be transferred so we can simply return
     * the task port back to the caller.
     */
    if(environment_supports_full_tfp())
    {
        return task;
    }
    
    /*
     * partially very narrow access, i was eperimenting with
     * the mach api till i stumbled upon this neat symbol
     * and its opponent which restores it back. so the
     * sender creates this transferable port and the
     * receiver stores it somewhere to then resend it..
     * the final receiver of this port can then extract
     * a valid task name out of this port.
     */
    kern_return_t kr = task_create_identity_token(task, &task);
    
    /*
     * if this doesnt work then hopefully it will send
     * nothing.
     */
    if(kr != KERN_SUCCESS)
    {
        return MACH_PORT_NULL;
    }
    
    return task;
}

void environment_tfp_extract_transfer_port(mach_port_t *tport)
{
    /*
     * when full tfp fix is supported that means that the task
     * port it self can be transferred so we can simply return.
     */
    if(environment_supports_full_tfp())
    {
        return;
    }
    
    /*
     * partially very narrow access, basically when someone receives
     * the transferable port they can then as a other process extract
     * a TASK NAME right out of this port, why did i capitlized that?
     * its because I dont want people to point out I could ask for a
     * more powerful flavor, iOS forbids that I already tried that
     * and wish this second method would allow for it. note that
     * regardless.. a task name right is still much more powerful
     * than no task right at all.
     */
    task_id_token_t token = *tport;
    
    kern_return_t kr = task_identity_token_get_task_port(token, TASK_FLAVOR_NAME, tport);
    
    /*
     * if this doesnt work then hopefully it will handle
     * nothing.
     */
    if(kr != KERN_SUCCESS)
    {
        *tport = MACH_PORT_NULL;
    }
    
    /*
     * releasing token to avoid a reference leak, since this is
     * about extracting the task port out of the tport pointer
     * so this port shall be gone now.
     */
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
        environment_syscall(SYS_sendtask, environment_tfp_create_transfer_port(mach_task_self()));
        
        /* hooking tfp api */
        litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, task_for_pid, environment_task_for_pid, nil);
        DO_HOOK_GLOBAL(task_name_for_pid);
    }
}
