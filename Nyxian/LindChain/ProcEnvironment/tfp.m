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
#import <LindChain/litehook/src/litehook.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <mach/mach.h>
#import <LindChain/ProcEnvironment/tpod.h>

kern_return_t environment_task_for_pid(mach_port_name_t tp_in,      /* tp_in is almost ignored because its obsolete for nyxians security model */
                                       pid_t pid,
                                       mach_port_name_t *tp_out)
{
    /* checking if tp_in is valid to match real behaviour */
    if(tp_out == NULL ||
       ![[[TaskPortObject alloc] initWithPort:tp_in] isUsable])
    {
        /* its not valid so failure */
        return KERN_FAILURE;
    }
    
    /* trying to first get tp_out from our userspace task port database */
    TaskPortObject *tpo = get_tpo_for_pid(pid);
    
    /* null pointer check */
    if(tpo == NULL)
    {
        /*
         * if tpo is null it either means it was unusable or that it was never in our database,
         * in that case we have to ask the kernel virtualisation layer nicely
         */
        tpo = environment_proxy_tfp_get_port_object_for_process_identifier(pid);
        
        /* trying to add tpo to tpod */
        if(!set_tpo_for_pid(pid, tpo))
        {
            /* we didnt so return KERN_FAILURE */
            return KERN_FAILURE;
        }
    }
    
    /* setting tp_out to tpo */
    *tp_out = [tpo port];
    
    /* increment the task port reference */
    mach_port_mod_refs(mach_task_self(), *tp_out, MACH_PORT_RIGHT_SEND, 1);
    
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
        tpod_init();
        
        if(environment_is_role(EnvironmentRoleGuest))
        {
            /* sending our task port to the task port system */
            [hostProcessProxy sendPort:[TaskPortObject taskPortSelf]];
            
            /* hooking task_for_pid(3) */
            litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, task_for_pid, environment_task_for_pid, nil);
        }
        else
        {
            /* setting tpo entry of our selves */
            set_tpo_for_pid(getpid(), [TaskPortObject taskPortSelf]);
        }
    }
}
