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

#import <LindChain/ProcEnvironment/Object/MachPortObject.h>
#import <xpc/xpc.h>

@implementation MachPortObject

- (instancetype)initWithPort:(mach_port_t)port
{
    self = [super init];
    _port = port;
    return self;
}

+ (BOOL)supportsSecureCoding
{
    return YES;
}

- (BOOL)isUsable
{
    mach_port_type_t type;
    kern_return_t kr = mach_port_type(mach_task_self(), _port, &type);

    if(kr != KERN_SUCCESS || type == MACH_PORT_TYPE_DEAD_NAME || type == 0)
    {
        // No rights to the task name?
        return NO;
    }
    else
    {
        // Its usable
        return YES;
    }
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder
{
    if([coder respondsToSelector:@selector(encodeXPCObject:forKey:)])
    {
        xpc_object_t dict = xpc_dictionary_create(NULL, NULL, 0);
        kern_return_t kr =  mach_port_mod_refs(mach_task_self(), _port, MACH_PORT_RIGHT_SEND, 1);
        if(kr == KERN_SUCCESS)
        {
            xpc_dictionary_set_mach_send(dict, "port", _port);
            [(id)coder encodeXPCObject:dict forKey:@"machPort"];
        }
    }
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    if([coder respondsToSelector:@selector(decodeXPCObjectOfType:forKey:)])
    {
        struct _xpc_type_s *dictType = (struct _xpc_type_s *)XPC_TYPE_DICTIONARY;
        NSObject<OS_xpc_object> *obj = [(id)coder decodeXPCObjectOfType:dictType
                                                                 forKey:@"machPort"];
        if(obj)
        {
            xpc_object_t dict = obj;
            mach_port_t port = xpc_dictionary_copy_mach_send(dict, "port");
            return [self initWithPort:port];
        }
    }
    return nil;
}

- (void)deinit
{
    [super deinit];
    if(_port != MACH_PORT_NULL)
    {
        mach_port_deallocate(mach_task_self(), _port);
        _port = MACH_PORT_NULL;
    }
}

@end
