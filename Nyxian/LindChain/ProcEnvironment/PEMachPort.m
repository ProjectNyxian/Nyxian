/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2025 - 2026 emexlab

 This file is part of Nyxian.

 Licensed under the emexLabs Public Source License, version 1.1
 (EPSL 1.1).

 Private use and modification are permitted under the license.
 Redistribution of source or binaries, modified or unmodified,
 requires prior written permission from emexLabs.

 External deployment is subject to the source-availability
 requirements and other conditions of the license.

 Provided "AS IS", without warranty, to the extent permitted by law.

 See LICENSE for the full license terms.
*/

#import <LindChain/ProcEnvironment/PEMachPort.h>
#import <xpc/xpc.h>

@implementation PEMachPort

+ (instancetype)portWithPortName:(mach_port_name_t)port
{
    return [[self alloc] initWithPortName:port];
}

- (instancetype)initWithPortName:(mach_port_name_t)port
{
    self = [super init];
    kern_return_t kr = mach_port_mod_refs(mach_task_self(), port, MACH_PORT_RIGHT_SEND, 1);
    if(kr != KERN_SUCCESS)
    {
        return nil;
    }
    _port = port;
    _sendOnce = false;
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
    xpc_object_t dict = xpc_dictionary_create(NULL, NULL, 0);
    if(dict)
    {
        mach_port_t receivePort = _port;
        if(_sendOnce)
        {
            mach_msg_type_name_t acquiredType;
            kern_return_t kr = mach_port_extract_right(mach_task_self(), _port, MACH_MSG_TYPE_MAKE_SEND_ONCE, &receivePort, &acquiredType);
            if(kr != KERN_SUCCESS || acquiredType != MACH_MSG_TYPE_MOVE_SEND_ONCE)
            {
                return;
            }
        }
        else
        {
            kern_return_t kr =  mach_port_mod_refs(mach_task_self(), _port, MACH_PORT_RIGHT_SEND, 1);
            if(kr != KERN_SUCCESS)
            {
                return;
            }
        }
    }
    xpc_dictionary_set_mach_send(dict, "port", _port);
    [(id)coder encodeXPCObject:dict forKey:@"machPort"];
}

- (nullable instancetype)initWithCoder:(nonnull NSCoder *)coder
{
    struct _xpc_type_s *dictType = (struct _xpc_type_s *)XPC_TYPE_DICTIONARY;
    NSObject<OS_xpc_object> *obj = [(id)coder decodeXPCObjectOfType:dictType forKey:@"machPort"];
    if(obj)
    {
        xpc_object_t dict = obj;
        mach_port_t port = xpc_dictionary_copy_mach_send(dict, "port");
        return [self initWithPortName:port];
    }
    return nil;
}

- (void)dealloc
{
    if(_port != MACH_PORT_NULL)
    {
        mach_port_deallocate(mach_task_self(), _port);
        _port = MACH_PORT_NULL;
    }
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone
{
    PEMachPort *copy = [[[self class] allocWithZone:zone] init];
    
    kern_return_t kr = mach_port_mod_refs(mach_task_self(), self.port, MACH_PORT_RIGHT_SEND, 1);
    if(kr != KERN_SUCCESS)
    {
        return nil;
    }
    
    copy->_port = self.port;
    
    return copy;
}

- (ipc_info_object_type_t)getIPCType
{
    ipc_info_object_type_t type;
    mach_vm_address_t placeholder;
    kern_return_t kr = mach_port_kobject(mach_task_self(), self.port, &type, &placeholder);
    if(kr != KERN_SUCCESS)
    {
        return IPC_OTYPE_NONE;
    }
    return type;
}

- (mach_port_urefs_t)getRefCnt
{
    mach_port_urefs_t ref;
    kern_return_t kr = mach_port_get_refs(mach_task_self(), self.port, MACH_PORT_RIGHT_SEND, &ref);
    if(kr != KERN_SUCCESS)
    {
        return 0;
    }
    return ref;
}

@end
