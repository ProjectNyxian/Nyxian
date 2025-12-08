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

#ifndef PROCENVIRONMENT_IOSERVER_IOCLIENT_H
#define PROCENVIRONMENT_IOSERVER_IOCLIENT_H

#import <mach/mach.h>

typedef struct io_client io_client_t;

/* creation and destruction */
io_client_t *io_client_create(mach_port_t port);
void io_client_destroy(io_client_t *client);

/* memory */
bool io_client_copy_mem_in(io_client_t *client, vm_address_t vm_client_address, vm_address_t vm_host_address, vm_size_t vm_size);
bool io_client_copy_mem_out(io_client_t *client, vm_address_t vm_client_address, vm_address_t vm_host_address, vm_size_t vm_size);

/* ports */
mach_port_t io_client_copy_port_in(io_client_t *client, mach_port_t *host_port, mach_port_t client_port);
mach_port_t io_client_copy_port_out(io_client_t *client, mach_port_t host_port, mach_port_t *client_port);

#endif /* PROCENVIRONMENT_IOSERVER_IOCLIENT_H */
