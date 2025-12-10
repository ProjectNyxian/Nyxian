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

vm_io_server_t *vm_io_server_create(void);
void vm_io_server_destroy(void);
void vm_io_server_start(vm_io_server_t *server);
void vm_io_server_stop(vm_io_server_t *server);
mach_port_t vm_io_server_getport(vm_io_server_t *server);

#endif /* VMIOSERVER_H */
