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

#ifndef VMIOSERVER_H
#define VMIOSERVER_H

#import <mach/mach.h>

typedef struct vm_io_server vm_io_server_t;

enum kVMIORequestType {
    kVMIORequestTypeCopyIn = 0,
    kVMIORequestTypeCopyOut = 1,
    kVMIORequestTypePortIn = 2,
    kVMIORequestTypePortOut = 3,
    //kVMIORequestTypeFDIn = 4,
    //kVMIORequestTypeFDOut = 5,
    kVMIORequestTypeTinyCopyIn = 6,
    kVMIORequestTypeTinyCopyOut = 7
};

typedef uint8_t vm_io_request_type_t;

typedef struct {
    mach_msg_header_t           header;
    mach_msg_body_t             body;
    mach_msg_port_descriptor_t  port_desc;
    mach_port_t port;
    vm_address_t address;
    vm_size_t size;
    vm_io_request_type_t type;
    uint8_t tiny_size;
    uint8_t tiny_payload[UINT8_MAX];
} vm_io_request_t;

typedef struct {
    mach_msg_header_t           header;
    mach_msg_body_t             body;
    mach_msg_port_descriptor_t  port_desc;
    mach_port_t port;
    bool suceeded;
    uint8_t tiny_size;
    uint8_t tiny_payload[UINT8_MAX];
} vm_io_reply_t;

vm_io_server_t *vm_io_server_create(void);
void vm_io_server_destroy(vm_io_server_t *server);
int vm_io_server_start(vm_io_server_t *server);
void vm_io_server_stop(vm_io_server_t *server);
mach_port_t vm_io_server_getport(vm_io_server_t *server);

#endif /* VMIOSERVER_H */
