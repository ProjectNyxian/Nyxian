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

#ifndef VMIOCLIENT_H
#define VMIOCLIENT_H

#import <mach/mach.h>

typedef struct vm_io_client vm_io_client_t;

typedef struct {
    vm_address_t map_address;
    vm_size_t map_size;
    mach_port_t mem_port;
} vm_io_client_map_t;

enum kVMIOClientError {
    kVMIOClientErrorSuccess = 0,
    kVMIOClientErrorFailure = 1
};

typedef uint8_t kvmio_error_t;

/* connection and destruction */
vm_io_client_t *kvmio_client_create(mach_port_t port);
void kvmio_client_destroy(vm_io_client_t *client);

/* allocation helper for the kernel */
vm_io_client_map_t *kvmio_alloc(vm_size_t map_size);
void kvmio_dealloc(vm_io_client_map_t *map);

/* virtual memory & input/output */
kvmio_error_t kvmio_copy_in(vm_io_client_t *client, vm_io_client_map_t *map, vm_address_t iovm_address);        /* copying memory from iovm server into kernel */
kvmio_error_t kvmio_copy_out(vm_io_client_t *client, vm_io_client_map_t *map, vm_address_t iovm_address);       /* copying memory from kernel into iovm server */
kvmio_error_t kvmio_port_in(vm_io_client_t *client, mach_port_t port_krnl, mach_port_t *port_iovm);             /* copying port from iovm server into kernel */
kvmio_error_t kvmio_port_out(vm_io_client_t *client, mach_port_t *port_krnl, mach_port_t port_iovm);            /* copying port from kernel into iovm server */
kvmio_error_t kvmio_tiny_copy_in(vm_io_client_t *client, vm_address_t krnl_address, vm_size_t krnl_size, vm_address_t iovm_address);
kvmio_error_t kvmio_tiny_copy_out(vm_io_client_t *client, vm_address_t krnl_address, vm_size_t krnl_size, vm_address_t iovm_address);

#endif /* VMIOCLIENT_H */
