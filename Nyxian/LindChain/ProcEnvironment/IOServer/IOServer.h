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

#ifndef PROCENVIRONMENT_IOSERVER_IOSERVER_H
#define PROCENVIRONMENT_IOSERVER_IOSERVER_H

#import <mach/mach.h>

enum kIOAction {
    kIOActionCopyMemoryIn = 0,
    kIOActionCopyMemoryOut = 1,
    kIOActionCopyPortIn = 2,
    kIOActionCopyPortOut = 3
};

typedef struct io_server io_server_t;

typedef struct {
    mach_msg_header_t           header;         /* mach message header */
    mach_msg_body_t             body;           /* mach message body */
    mach_msg_port_descriptor_t  port;           /* always a descriptor.. for memory ports and such */
    uint8_t                     act;            /* declares io action */
    vm_address_t                r_addr;         /* requested address */
    vm_size_t                   r_size;         /* requested size */
    mach_port_t                 r_port;         /* requested port */
} io_request_t;

typedef struct {
    mach_msg_header_t           header;         /* mach message header */
    mach_msg_body_t             body;           /* mach message body */
    mach_msg_port_descriptor_t  port;           /* always a descriptor.. for memory ports and such */
    vm_size_t                   m_size;         /* size of memory port if applicable */
    vm_size_t                   w_size;         /* written size */
    bool                        success;        /* succession */
} io_reply_t;

io_server_t *io_server_create(void);
void io_server_destroy(io_server_t *server);
int io_server_start(io_server_t *server);
void io_server_stop(io_server_t *server);
mach_port_t io_server_get_port(io_server_t *server);

#endif /* PROCENVIRONMENT_IOSERVER_IOSERVER_H */
