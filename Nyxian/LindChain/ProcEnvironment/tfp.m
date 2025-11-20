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
#import <LindChain/ProcEnvironment/Surface/proc.h>
#import <mach/mach.h>

static NSMutableDictionary <NSNumber*,TaskPortObject*> *tfp_userspace_ports;

kern_return_t environment_task_for_pid(mach_port_name_t taskPort,
                                       pid_t pid,
                                       mach_port_name_t *requestTaskPort)
{
    // Ignore input task port, literally take from `tfp_userspace_ports`
    MachPortObject *machPortObject = [tfp_userspace_ports objectForKey:@(pid)];
    if(machPortObject)
    {
        if([machPortObject isUsable])
        {
            // We got machPortObject so insert it into `requestedTask`
            *requestTaskPort = [machPortObject port];
        }
        else
        {
            [tfp_userspace_ports removeObjectForKey:@(pid)];
            return KERN_FAILURE;
        }
    }
    else
    {
        if(environment_is_role(EnvironmentRoleHost))
        {
            // No machPortObject, so deny
            return KERN_FAILURE;
        }
        else
        {
            // Asking the host application for the port object that contains the task port of the pid
            TaskPortObject *portObject = environment_proxy_tfp_get_port_object_for_process_identifier(pid);
            
            // If the port is valid, we save it
            if(!portObject)
                return KERN_FAILURE;
            else
                [tfp_userspace_ports setObject:portObject forKey:@(pid)];
            
            // now we set `requestTaskPort`
            *requestTaskPort = [portObject port];
        }
    }
    
    // MARK: Possibly fixes the bug we had
    mach_port_mod_refs(mach_task_self(), *requestTaskPort, MACH_PORT_RIGHT_SEND, 1);
    
    return KERN_SUCCESS;
}

DEFINE_HOOK(task_policy_get, kern_return_t,(task_policy_get_t task,
                                            task_policy_flavor_t flavor,
                                            task_policy_t policy_info,
                                            mach_msg_type_number_t *policy_infoCnt,
                                            boolean_t *get_default))
{
    kern_return_t kr = ORIG_FUNC(task_policy_get)(task, flavor, policy_info, policy_infoCnt, get_default);
    
    if(kr == KERN_SUCCESS
       && flavor == TASK_CATEGORY_POLICY)
    {
        pid_t pid = 0;
        kr = pid_for_task(task, &pid);
        if(kr == KERN_SUCCESS)
        {
            ksurface_proc_t proc = {};
            ksurface_error_t error = proc_for_pid(pid, &proc);
            if(error != kSurfaceErrorSuccess
               && proc.force_task_role_override)
            {
                task_category_policy_data_t *data = (task_category_policy_data_t*)policy_info;
                data->role = proc.task_role_override;
            }
        }
    }
    
    return kr;
}

void environment_host_take_client_task_port(TaskPortObject *machPort)
{
    environment_must_be_role(EnvironmentRoleHost);
    if([machPort isUsable] && [machPort port] != mach_task_self())
    {
        pid_t pid = 0;
        kern_return_t kr = pid_for_task([machPort port], &pid);
        if(kr == KERN_SUCCESS && pid != getpid()) [tfp_userspace_ports setObject:machPort forKey:@(pid)];
    }
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
        tfp_userspace_ports = [[NSMutableDictionary alloc] init];
        
        if(environment_is_role(EnvironmentRoleGuest))
        {
            // MARK: Guest Init
            [hostProcessProxy sendPort:[TaskPortObject taskPortSelf]];
            litehook_rebind_symbol(LITEHOOK_REBIND_GLOBAL, task_for_pid, environment_task_for_pid, nil);
            DO_HOOK_GLOBAL(task_policy_get);
        }
        else
        {
            // MARK: Host Init
            [tfp_userspace_ports setObject:[TaskPortObject taskPortSelf] forKey:@(getpid())];
        }
    }
}
