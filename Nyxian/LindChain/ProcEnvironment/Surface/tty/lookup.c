/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 mach-port-t

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

#include <LindChain/ProcEnvironment/Surface/surface.h>
#include <LindChain/ProcEnvironment/Surface/tty/lookup.h>
#include <LindChain/LiveContainer/Tweaks/libproc.h>

kern_return_t tty_for_port(fileport_t port,
                           ksurface_tty_t **tty)
{
    /* sanity check */
    if(tty == NULL)
    {
        return KERN_INVALID_ADDRESS;
    }
    
    /* getting file descriptor */
    int fd = fileport_makefd(port);
    
    /* validating file descriptor */
    if(fd < 0)
    {
        return KERN_FAILURE;
    }
    
    /* getting unique object pointer */
    struct socket_fdinfo si;
    
    if(proc_pidfdinfo(getpid(), fd, PROC_PIDFDSOCKETINFO, &si, sizeof(si)) <= 0)
    {
        close(fd);
        return KERN_FAILURE;
    }
    
    /* disposing that fd, not needed rn */
    close(fd);
    
    /* tty tree lookup */
    tty_table_rdlock();
    *tty = radix_lookup(&(ksurface->tty_info.tty), si.psi.soi_proto.pri_kern_ctl.kcsi_id);
    tty_table_unlock();
    
    /*
     * caller expects retained tty object, so
     * attempting to retain it and if it doesnt work
     * returning with an error.
     */
    if(*tty == NULL ||
       !kvo_retain(*tty))
    {
        return KERN_FAILURE;
    }
    
    return KERN_SUCCESS;
}
