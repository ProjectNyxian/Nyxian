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

#include <LindChain/ProcEnvironment/Surface/libkern/pthread.h>
#include <LindChain/ProcEnvironment/Surface/sys/host/ioctl.h>
#include <LindChain/ProcEnvironment/Surface/tty/tty.h>
#include <LindChain/ProcEnvironment/Surface/proc/list.h>
#include <termios.h>
#include <errno.h>

DEFINE_SYSCALL_HANDLER(ioctl)
{
    sys_need_in_ports(1, MACH_MSG_TYPE_MOVE_SEND);
    
    fileport_t u_port = sys_in_ports[0];
    unsigned long u_flag = (unsigned long)args[1];
    userspace_pointer_t u_ptr = (userspace_pointer_t)args[2];
    
    switch(u_flag)
    {
        case TIOCGETA:
        case TIOCSETA:
        case TIOCSETAW:
        case TIOCSETAF:
        case TIOCSPGRP:
        case TIOCGPGRP:
        case TIOCGWINSZ:
        case TIOCSWINSZ:
        case TIOCSCTTY:
            break;
        default:
            sys_return_failure_with_errno(ENOSYS);
    }
    
    ksurface_tty_t *tty = NULL;
    kern_return_t kr = tty_for_port(u_port, &tty);
    if(kr != KERN_SUCCESS)
    {
        sys_return_failure_with_errno(ENOTTY);
    }
    
    switch(u_flag)
    {
        case TIOCGETA:
        {
            kvo_rdlock(tty);
            if(!syscall_copy_out(sys_task_, sizeof(struct termios), &(tty->t), u_ptr))
            {
                goto out_fault;
            }
            break;
        }
        case TIOCSETA:
        case TIOCSETAW:
        case TIOCSETAF:
        {
            kvo_wrlock(tty);
            
            struct termios temp;
            if(!syscall_copy_in(sys_task_, sizeof(struct termios), &temp, u_ptr))
            {
                goto out_fault;
            }
            
            if(pthread_suspend(tty->pump_thread) != 0)
            {
                goto out_fault;
            }
            
            memcpy(&(tty->t), &temp, sizeof(struct termios));
            pthread_resume(tty->pump_thread);
            break;
        }
        case TIOCSPGRP:
        {
            kvo_wrlock(tty);
            
            pid_t requested = 0;
            if(!syscall_copy_in(sys_task_, sizeof(requested), &requested, u_ptr))
            {
                goto out_fault;
            }
            
            pid_t caller_sid = proc_getsid(sys_proc_snapshot_);
            if(tty->sid != caller_sid)
            {
                goto out_notty;
            }
            
            if(requested <= 0 || !proc_pgrp_exists_in_session(requested, caller_sid))
            {
                goto out_perm;
            }
            
            tty->pgrp = requested;
            break;
        }
        case TIOCGPGRP:
        {
            kvo_rdlock(tty);
            
            if(tty->sid != proc_getsid(sys_proc_snapshot_))
            {
                goto out_notty;
            }
            
            if(!syscall_copy_out(sys_task_, sizeof(pid_t), &(tty->pgrp), u_ptr))
            {
                goto out_fault;
            }
            break;
        }

        case TIOCGWINSZ:
        {
            kvo_rdlock(tty);
            if(!syscall_copy_out(sys_task_, sizeof(struct winsize), &(tty->ws), u_ptr))
            {
                goto out_fault;
            }
            break;
        }

        case TIOCSWINSZ:
        {
            kvo_wrlock(tty);
            struct winsize temp;
            
            if(!syscall_copy_in(sys_task_, sizeof(struct winsize), &temp, u_ptr))
            {
                goto out_fault;
            }
            
            bool changed = tty->ws.ws_row != temp.ws_row || tty->ws.ws_col != temp.ws_col || tty->ws.ws_xpixel != temp.ws_xpixel || tty->ws.ws_ypixel != temp.ws_ypixel;
            tty->ws = temp;
            kvo_unlock(tty);
            if(changed)
            {
                tty_kill(tty, SIGWINCH);
            }
            
            kvo_release(tty);
            sys_return;
        }
        case TIOCSCTTY:
        {
            kvo_wrlock(tty);
            
            pid_t pid = proc_getpid(sys_proc_snapshot_);
            pid_t sid = proc_getsid(sys_proc_snapshot_);
            pid_t pgid = proc_getpgid(sys_proc_snapshot_);
            if(pid != sid)
            {
                goto out_perm;
            }
            
            if(tty->sid != 0 && tty->sid != sid)
            {
                goto out_perm;
            }
            
            tty->sid = sid;
            tty->pgrp = pgid;
            kvo_unlock(tty);
            
            kvo_wrlock(sys_proc_);
            sys_proc_->bsd.kp_proc.p_flag |= P_CONTROLT;
            sys_proc_->bsd.kp_eproc.e_tpgid = pgid;
            kvo_unlock(sys_proc_);
            
            kvo_release(tty);
            sys_return;
        }
    }
    
    kvo_unlock(tty);
    kvo_release(tty);
    sys_return;
    
out_fault:
    kvo_unlock(tty);
    kvo_release(tty);
    sys_return_failure_with_errno(EFAULT);
    
out_perm:
    kvo_unlock(tty);
    kvo_release(tty);
    sys_return_failure_with_errno(EPERM);
    
out_notty:
    kvo_unlock(tty);
    kvo_release(tty);
    sys_return_failure_with_errno(ENOTTY);
}
