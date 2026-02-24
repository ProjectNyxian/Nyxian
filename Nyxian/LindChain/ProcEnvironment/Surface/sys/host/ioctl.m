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

#import <LindChain/ProcEnvironment/Surface/sys/host/ioctl.h>
#import <LindChain/ProcEnvironment/Surface/tty/tty.h>
#include <termios.h>

DEFINE_SYSCALL_HANDLER(ioctl)
{
    sys_name("SYS_ioctl");
    sys_need_in_ports_with_cnt(1);
    
    /* prepare arguments */
    fileport_t port = in_ports[0];
    int flag = (int)args[1];
    /* userspace_pointer_t termios_ptr = (userspace_pointer_t)args[2]; MARK: coming later */
    
    /* compatibility flag */
    if(flag != TIOCGETA)
    {
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
    
    sys_return;
}
