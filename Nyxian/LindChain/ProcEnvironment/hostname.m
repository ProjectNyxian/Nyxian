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

#import <LindChain/ProcEnvironment/hostname.h>
#import <LindChain/ProcEnvironment/environment.h>
#import <LindChain/litehook/litehook.h>
#import <LindChain/ProcEnvironment/proxy.h>
#import <LindChain/ProcEnvironment/syscall.h>

DEFINE_HOOK(gethostname, int, (char *name,
                               size_t len))
{
    /* casting length */
    uint32_t len32 = (uint32_t)len;
    
    int retval = (int)environment_syscall(SYS_gethostname, name, &len32);
    
    /* null terminating string */
    name[len32] = '\0';
    
    /* calling ksurface syscall server */
    return retval;
}

DEFINE_HOOK(sethostname, int, (char *name,
                               size_t len))
{
    /* casting length */
    uint32_t len32 = (uint32_t)len;
    
    /* calling ksurface syscall server */
    return (int)environment_syscall(SYS_sethostname, (void*)name, len32);
}

void environment_hostname_init(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        if(environment_is_role(EnvironmentRoleGuest))
        {
            DO_HOOK_GLOBAL(gethostname);
            DO_HOOK_GLOBAL(sethostname);
        }
    });
}
