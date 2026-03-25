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

#import <Foundation/Foundation.h>
#import <LindChain/ProcEnvironment/Surface/sys/compat/pectl.h>
#import <LindChain/LaunchServices/LDEBootstrapRegistry.h>
#import <LindChain/ProcEnvironment/Server/Server.h>

extern mach_port_t xpc_endpoint_copy_listener_port_4sim(NSObject<OS_xpc_object>*);
extern NSObject<OS_xpc_object> *xpc_endpoint_create_mach_port_4sim(mach_port_t port);

DEFINE_SYSCALL_HANDLER(pectl)
{
    uint8_t action = (uint8_t)args[0];
    
    switch(action)
    {
        case PECTL_GET_ENDPOINT:
        {
            if(!entitlement_got_entitlement(proc_getentitlements(sys_proc_snapshot_), PEEntitlementLaunchServicesGetEndpoint))
            {
                sys_return_failure(EPERM);
            }
            
            userspace_pointer_t userspace_str = (userspace_pointer_t)args[1];
            
            char *service_name = mach_syscall_copy_str_in(sys_task_, userspace_str, MAXHOSTNAMELEN);
            if(service_name == NULL)
            {
                sys_return_failure(ENOMEM);
            }
            
            NSString *service_nsname = [NSString stringWithCString:service_name encoding:NSUTF8StringEncoding];
            free(service_name);
            if(service_nsname == nil)
            {
                sys_return_failure(ENOMEM);
            }
            
            NSXPCListenerEndpoint *endpoint = [[LDEBootstrapRegistry shared] getEndpointWithServiceIdentifier:service_nsname];
            if(endpoint == nil)
            {
                sys_return_failure(EACCES);
            }
            
            mach_port_t port = xpc_endpoint_copy_listener_port_4sim(endpoint._endpoint);
            if(port == MACH_PORT_NULL)
            {
                sys_return_failure(EACCES);
            }
            
            kern_return_t kr = mach_port_mod_refs(mach_task_self(), port, MACH_PORT_RIGHT_SEND, 1);
            if(kr != KERN_SUCCESS)
            {
                sys_return_failure(EACCES);
            }
            
            kr = mach_syscall_payload_create(NULL, sizeof(mach_port_t), (vm_address_t*)out_ports);
            if(kr != KERN_SUCCESS)
            {
                mach_port_deallocate(mach_task_self(), port);
                sys_return_failure(ENOMEM);
            }
            
            (*out_ports)[0] = port;
            *out_ports_cnt = 1;
        }
        case PECTL_SET_ENDPOINT:
        {
            sys_need_in_ports(1, MACH_MSG_TYPE_MOVE_SEND);
            
            if(!entitlement_got_entitlement(proc_getentitlements(sys_proc_snapshot_), PEEntitlementPlatform))
            {
                sys_return_failure(EPERM);
            }
            
            NSXPCListenerEndpoint *endpoint = [[NSXPCListenerEndpoint alloc] init];
            endpoint._endpoint = xpc_endpoint_create_mach_port_4sim(sys_in_ports[0]);
            if(endpoint == nil || endpoint._endpoint == nil)
            {
                sys_return_failure(EACCES);
            }
            
            userspace_pointer_t userspace_str = (userspace_pointer_t)args[1];
            
            char *service_name = mach_syscall_copy_str_in(sys_task_, userspace_str, MAXHOSTNAMELEN);
            if(service_name == NULL)
            {
                sys_return_failure(ENOMEM);
            }
            
            NSString *service_nsname = [NSString stringWithCString:service_name encoding:NSUTF8StringEncoding];
            free(service_name);
            if(service_nsname == nil)
            {
                sys_return_failure(ENOMEM);
            }
            
            [[LDEBootstrapRegistry shared] setEndpoint:endpoint forServiceIdentifier:service_nsname];
            sys_in_ports[0] = MACH_PORT_NULL;   /* prevent mach port reference leak */
            
            sys_return;
            break;
        }
        default:
            break;
    }
    
    sys_return_failure(ENOSYS);
}
