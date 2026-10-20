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

#include <LindChain/ProcEnvironment/Surface/sys/host/openpty.h>
#include <LindChain/ProcEnvironment/Surface/tty/tty.h>
#include <LindChain/Private/mach/fileport.h>
#include <mach/mach.h>
#include <errno.h>
#include <string.h>
#include <termios.h>

DEFINE_SYSCALL_HANDLER(openpty)
{
    ksurface_tty_t *tty = kvo_alloc_fastpath(tty);
    if(tty == NULL)
    {
        sys_return_failure_with_errno(ENOMEM);
    }
    
    kvo_wrlock(tty);
    memset(&tty->t, 0, sizeof(tty->t));
    memset(&tty->ws, 0, sizeof(tty->ws));
    tty->sid = 0;
    tty->pgrp = 0;
    
    tty->t.c_iflag = ICRNL | ISTRIP | INPCK;
    tty->t.c_oflag = OPOST | ONLCR;
    tty->t.c_lflag = ISIG;
    
    tty->t.c_cc[VINTR] = 0x03;
    tty->t.c_cc[VQUIT] = 0x1c;
    tty->t.c_cc[VKILL] = 0x15;
    tty->t.c_cc[VSUSP] = 0x1a;
    
    tty->ws.ws_col = 80;
    tty->ws.ws_row = 24;
    
    kvo_unlock(tty);
    
    fileport_t master_port = MACH_PORT_NULL;
    fileport_t slave_port = MACH_PORT_NULL;
    if(fileport_makeport(tty->userspacefd[MASTERFD], &master_port) != 0)
    {
        kvo_release(tty);
        sys_return_failure_with_errno(EBADF);
    }
    
    if(fileport_makeport(tty->userspacefd[SLAVEFD], &slave_port) != 0)
    {
        mach_port_deallocate(mach_task_self(), master_port);
        kvo_release(tty);
        sys_return_failure_with_errno(EBADF);
    }
    
    kern_return_t kr = tty_hold_proc(sys_proc_, tty);
    if(kr != KERN_SUCCESS)
    {
        mach_port_deallocate(mach_task_self(), master_port);
        mach_port_deallocate(mach_task_self(),slave_port);
        kvo_release(tty);
        sys_return_failure_with_errno(EIO);
    }
    
    kr = syscall_payload_create(NULL, sizeof(mach_port_t) * 2, (mach_vm_address_t*)out_ports);
    if(kr != KERN_SUCCESS)
    {
        mach_port_deallocate(mach_task_self(), master_port);
        mach_port_deallocate(mach_task_self(), slave_port);
        sys_return_failure_with_errno(ENOMEM);
    }
    sys_export_port(master_port);
    sys_export_port(slave_port);
    
    sys_return;
}
