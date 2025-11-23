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

typedef struct {
    int *name;
    u_int namelen;
    void *__sized_by(*oldlenp) oldp;
    size_t *oldlenp;
    void *__sized_by(newlen) newp;
    size_t newlen;
} sysctl_req_t;

int sysctl_kernmaxproc(sysctl_req_t req)
{
    if(req.oldp && req.oldlenp && *(req.oldlenp) >= sizeof(int))
    {
        *(int *)(req.oldp) = PROC_MAX;
        *(req.oldlenp) = sizeof(int);
        return 0;
    }
    
    if(req.oldlenp)
    {
        *(req.oldlenp) = sizeof(int);
        return 0;
    }
    
    errno = EINVAL;
    return -1;
}

int sysctl_kernprocall(sysctl_req_t req)
{
    if(!req.oldlenp)
    {
        errno = EINVAL;
        return -1;
    }
    
    size_t needed = proc_sysctl_listproc(NULL, 0, NULL);
    
    if(req.oldp == NULL || *(req.oldlenp) == 0)
    {
        *(req.oldlenp) = needed;
        return 0;
    }
    
    if(*(req.oldlenp) < needed)
    {
        *(req.oldlenp) = needed;
        errno = ENOMEM;
        return -1;
    }
    
    int written = proc_sysctl_listproc(req.oldp, *(req.oldlenp), NULL);
    if(written < 0) return -1;
    
    *(req.oldlenp) = written;
    return 0;
}

int sysctl_kernprocargs2(sysctl_req_t req)
{
    if(req.oldlenp)
    {
        if(req.oldp && *(req.oldlenp) >= sizeof(int))
        {
            *(int *)(req.oldp) = 0;
            *(req.oldlenp) = sizeof(int);
            return 0;
        }
        *(req.oldlenp) = sizeof(int);
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
    sysctl_req_t req = {
        .name = name,
        .namelen = namelen,
        .oldp = oldp,
        .oldlenp = oldlenp,
        .newp = newp,
        .newlen = newlen,
    };
    
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
                            return sysctl_kernmaxproc(req);
                        case KERN_PROC:
                            if(namelen > 2)
                            {
                                switch(name[2])
                                {
                                    case KERN_PROC_ALL:
                                        return sysctl_kernprocall(req);
                                    default:
                                        break;
                                }
                            }
                        case KERN_PROCARGS2:
                            return sysctl_kernprocargs2(req);
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
