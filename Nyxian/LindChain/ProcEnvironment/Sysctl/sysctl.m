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

#import <LindChain/ProcEnvironment/Sysctl/sysctl.h>
#import <LindChain/ProcEnvironment/environment.h>
#import <LindChain/litehook/src/litehook.h>
#import <LindChain/ProcEnvironment/Surface/surface.h>
#import <LindChain/ProcEnvironment/Sysctl/kern/kern.h>

static const int mib_kern_maxproc[]    = { CTL_KERN, KERN_MAXPROC };
static const int mib_kern_proc_all[]   = { CTL_KERN, KERN_PROC, KERN_PROC_ALL };
static const int mib_kern_procargs2[]  = { CTL_KERN, KERN_PROCARGS2 };

static const sysctl_map_entry_t sysctl_map[] = {
    { mib_kern_maxproc,   2, sysctl_kernmaxproc },
    { mib_kern_proc_all,  3, sysctl_kernprocall },
    { mib_kern_procargs2, 2, sysctl_kernprocargs2 }
};

static sysctl_fn_t sysctl_lookup(sysctl_req_t *req)
{
    for (size_t i = 0; i < sizeof(sysctl_map)/sizeof(sysctl_map[0]); i++)
    {
        const sysctl_map_entry_t *e = &sysctl_map[i];
        
        if (req->namelen < e->mib_len)
        {
            continue;
        }
        
        bool match = true;
        for(size_t j = 0; j < e->mib_len; j++)
        {
            if(req->name[j] != e->mib[j])
            {
                match = false;
                break;
            }
        }
        
        if(match)
        {
            return e->fn;
        }
    }
    
    return NULL;
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
    
    sysctl_fn_t fn = sysctl_lookup(&req);
    if(fn != NULL) return fn(&req);
    
    return ORIG_FUNC(sysctl)(name, namelen, oldp, oldlenp, newp, newlen);
}

void environment_sysctl_init(void)
{
    if(environment_is_role(EnvironmentRoleGuest))
    {
        DO_HOOK_GLOBAL(sysctl)
    }
}
