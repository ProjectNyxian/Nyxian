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

#import <LindChain/ProcEnvironment/Surface/sys/host/ioctl.h>
#import <LindChain/ProcEnvironment/Surface/tty/tty.h>
#import <LindChain/ProcEnvironment/Surface/tty/utils.h>
#include <termios.h>

DEFINE_SYSCALL_HANDLER(ioctl)
{
    sys_need_in_ports(1, MACH_MSG_TYPE_MOVE_SEND);
    
    /* prepare arguments */
    fileport_t port = sys_in_ports[0];
    unsigned long flag = (unsigned long)args[1];
    userspace_pointer_t user_ptr = (userspace_pointer_t)args[2];
    
    switch(flag)
    {
        case TIOCGETA:
        case TIOCSETA:
        case TIOCSPGRP:
        case TIOCGPGRP:
        case TIOCGWINSZ:
            break;
        default:
            sys_return_failure(ENOSYS);
    }
    
    /* looking up tty */
    ksurface_tty_t *tty = NULL;
    ksurface_return_t ksr = tty_for_port(port, &tty);
    
    /* final check */
    if(ksr != SURFACE_SUCCESS)
    {
        sys_return_failure(ENOTTY);
    }
    
    /* ioctl paths */
    switch(flag)
    {
        case TIOCGETA:
            kvo_rdlock(tty);
            
            if(!mach_syscall_copy_out(sys_task_, sizeof(struct termios), &(tty->t), user_ptr))
            {
                goto out_fault;
            }
            
            break;
        case TIOCSETA:
            kvo_wrlock(tty);
            
            /* there is no rollback from a failed copy-in */
            struct termios temp;
            
            if(!mach_syscall_copy_in(sys_task_, sizeof(struct termios), &(temp), user_ptr))
            {
                goto out_fault;
            }
            
            ksurface_return_t ksr = tty_suspend(tty);
            if(ksr != SURFACE_SUCCESS)
            {
                goto out_fault;
            }
            
            /* TODO: sanitize fields, dont trust user memory blindly otherwise this could lead to a panic where the tty thread parses illegal data from termios */
            memcpy(&(tty->t), &temp, sizeof(struct termios));
            
            tty_resume(tty);
            
            break;
        case TIOCSPGRP:
            kvo_wrlock(tty);
            pid_t user_pgrp = 0;
            
            if(!mach_syscall_copy_in(sys_task_, sizeof(pid_t), &user_pgrp, user_ptr))
            {
                goto out_fault;
            }
            
            if(!mach_syscall_copy_out(sys_task_, sizeof(pid_t), &(tty->pgrp), user_ptr))
            {
                goto out_fault;
            }
            
            /* check if its allowed TODO: implement true pgrp support */
            if(proc_getsid(proc_snapshot) != user_pgrp)
            {
                goto out_perm;
            }
            
            if(!mach_syscall_copy_out(sys_task_, sizeof(pid_t), &user_pgrp, user_ptr))
            {
                goto out_fault;
            }
            
            break;
        case TIOCGPGRP:
            kvo_rdlock(tty);
            if(!mach_syscall_copy_out(sys_task_, sizeof(pid_t), &(tty->pgrp), user_ptr))
            {
                goto out_fault;
            }
            break;
        case TIOCGWINSZ:
            kvo_rdlock(tty);
            if(!mach_syscall_copy_out(sys_task_, sizeof(struct winsize), &(tty->ws), user_ptr))
            {
                goto out_fault;
            }
            break;
    }
    
    /* mutual deinit */
    kvo_unlock(tty);
    kvo_release(tty);
    sys_return;
    
out_fault:
    kvo_unlock(tty);
    kvo_release(tty);
    sys_return_failure(EFAULT);

out_perm:
    kvo_unlock(tty);
    kvo_release(tty);
    sys_return_failure(EPERM);
}
