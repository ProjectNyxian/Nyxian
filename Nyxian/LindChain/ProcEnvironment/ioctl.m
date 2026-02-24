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

#import <LindChain/ProcEnvironment/environment.h>
#import <LindChain/ProcEnvironment/ioctl.h>
#import <LindChain/ProcEnvironment/syscall.h>
#import <LindChain/litehook/litehook.h>
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

void environment_ioctl_init(void)
{
    if(environment_is_role(EnvironmentRoleGuest))
    {
        DO_HOOK_GLOBAL(ioctl);
    }
}
