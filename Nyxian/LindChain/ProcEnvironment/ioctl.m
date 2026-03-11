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

#import <LindChain/ProcEnvironment/environment.h>
#import <LindChain/ProcEnvironment/ioctl.h>
#import <LindChain/ProcEnvironment/syscall.h>
#import <LindChain/litehook/litehook.h>
#include <termios.h>
#include <sys/ioctl.h>

DEFINE_HOOK(ioctl, int, (int fd,
                         unsigned long flag,
                         ...))
{
    /* starting variadic argument parse */
    va_list args;
    va_start(args, flag);
    
    /* parsing arguments */
    int64_t sys_args[7];
    for(uint8_t i = 0; i < 6; i++)
    {
        sys_args[i] = va_arg(args, int64_t);
    }
    
    /* ending parse */
    va_end(args);
    
    int ret = (int)environment_syscall(SYS_ioctl, fd, flag, sys_args[0], sys_args[1], sys_args[2], sys_args[3], sys_args[4], sys_args[5], sys_args[6]);
    
    if(ret != 0 &&
       errno == ENOSYS)
    {
        return ORIG_FUNC(ioctl)(fd, flag, sys_args[0], sys_args[1], sys_args[2], sys_args[3], sys_args[4], sys_args[5], sys_args[6]);
    }
    
    return ret;
}

DEFINE_HOOK(isatty, int, (int fd))
{
    struct termios termios;
    return environment_syscall(SYS_ioctl, fd, TIOCGETA, &termios) == 0;
}

DEFINE_HOOK(tcgetattr, int, (int fd,
                             struct termios *t))
{
    return (int)environment_syscall(SYS_ioctl, fd, TIOCGETA, t);
}

DEFINE_HOOK(tcsetattr, int, (int fd,
                             int options,
                             struct termios *t))
{
    unsigned long req;

    switch(options)
    {
        case TCSANOW:
            req = TIOCSETA;
            break;
        case TCSADRAIN:
            req = TIOCSETAW;
            break;
        case TCSAFLUSH:
            req = TIOCSETAF;
            break;
        default:
            errno = EINVAL;
            return -1;
    }
    
    return (int)environment_syscall(SYS_ioctl, fd, req, t);
}

DEFINE_HOOK(tcsetpgrp, int, (int fd,
                             pid_t pgrp))
{
    return (int)environment_syscall(SYS_ioctl, fd, TIOCSPGRP, &pgrp);
}

DEFINE_HOOK(tcgetpgrp, int, (int fd))
{
    pid_t pgrp = 0;
    int ret = (int)environment_syscall(SYS_ioctl, fd, TIOCGPGRP, &pgrp);
    return (ret == 0) ? pgrp : -1;
}

void environment_ioctl_init(void)
{
    if(environment_is_role(EnvironmentRoleGuest))
    {
        DO_HOOK_GLOBAL(ioctl);
        DO_HOOK_GLOBAL(isatty);
        DO_HOOK_GLOBAL(tcgetattr);
        DO_HOOK_GLOBAL(tcsetattr);
        DO_HOOK_GLOBAL(tcsetpgrp);
        DO_HOOK_GLOBAL(tcgetpgrp);
    }
}
