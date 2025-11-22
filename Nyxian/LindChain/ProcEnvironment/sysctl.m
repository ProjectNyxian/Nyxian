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

#import <LindChain/ProcEnvironment/sysctl.h>
#import <LindChain/ProcEnvironment/environment.h>
#import <LindChain/litehook/src/litehook.h>
#import <LindChain/ProcEnvironment/Surface/surface.h>
#include <sys/sysctl.h>

int sysctl_kernmaxproc(int *name,
                       u_int namelen,
                       void *__sized_by(*oldlenp) oldp,
                       size_t *oldlenp,
                       void *__sized_by(newlen) newp,
                       size_t newlen)
{
    if(oldp && oldlenp && *oldlenp >= sizeof(int))
    {
        *(int *)oldp = PROC_MAX;
        *oldlenp = sizeof(int);
        return 0;
    }
    
    if(oldlenp)
    {
        *oldlenp = sizeof(int);
        return 0;
    }
    
    errno = EINVAL;
    return -1;
}

int sysctl_kernprocall(int *name,
                       u_int namelen,
                       void *__sized_by(*oldlenp) oldp,
                       size_t *oldlenp,
                       void *__sized_by(newlen) newp,
                       size_t newlen)
{
    if(!oldlenp)
    {
        errno = EINVAL;
        return -1;
    }
    
    size_t needed = proc_sysctl_listproc(NULL, 0, NULL);
    
    if(oldp == NULL || *oldlenp == 0)
    {
        *oldlenp = needed;
        return 0;
    }
    
    if(*oldlenp < needed)
    {
        *oldlenp = needed;
        errno = ENOMEM;
        return -1;
    }
    
    int written = proc_sysctl_listproc(oldp, *oldlenp, NULL);
    if(written < 0) return -1;
    
    *oldlenp = written;
    return 0;
}

int sysctl_kernprocargs2(int *name,
                         u_int namelen,
                         void *__sized_by(*oldlenp) oldp,
                         size_t *oldlenp,
                         void *__sized_by(newlen) newp,
                         size_t newlen)
{
    pid_t pid = name[2];
    if (oldlenp) {
        if (oldp && *oldlenp >= sizeof(int)) {
            *(int *)oldp = 0;
            *oldlenp = sizeof(int);
            return 0;
        }
        *oldlenp = sizeof(int);
        return 0;
    }
    
    errno = EINVAL;
    return -1;
}

DEFINE_HOOK(sysctl, int, (int *name,
                          u_int namelen,
                          void *__sized_by(*oldlenp) oldp,
                          size_t *oldlenp,
                          void *__sized_by(newlen) newp,
                          size_t newlen))
{
    if(namelen > 0)
    {
        switch(name[0])
        {
            case CTL_KERN:
                if(namelen > 1)
                {
                    switch(name[1])
                    {
                        case KERN_MAXPROC:
                            return sysctl_kernmaxproc(name, namelen, oldp, oldlenp, newp, newlen);
                        case KERN_PROC:
                            if(namelen > 2)
                            {
                                switch(name[2])
                                {
                                    case KERN_PROC_ALL:
                                        return sysctl_kernprocall(name, namelen, oldp, oldlenp, newp, newlen);
                                    default:
                                        break;
                                }
                            }
                        case KERN_PROCARGS2:
                            return sysctl_kernprocargs2(name, namelen, oldp, oldlenp, newp, newlen);
                        default:
                            break;
                    }
                }
            default:
                break;
        }
    }
    
    return ORIG_FUNC(sysctl)(name, namelen, oldp, oldlenp, newp, newlen);
}

void environment_sysctl_init(void)
{
    if(environment_is_role(EnvironmentRoleGuest))
    {
        DO_HOOK_GLOBAL(sysctl)
    }
}
