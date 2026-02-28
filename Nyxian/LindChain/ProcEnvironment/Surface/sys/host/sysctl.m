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

#import <LindChain/ProcEnvironment/Surface/sys/host/sysctl.h>
#import <LindChain/ProcEnvironment/Surface/proc/list.h>
#include <sys/sysctl.h>
#include <regex.h>
#import <Foundation/Foundation.h>

/* sysctl defs */
typedef struct {
    int name[6];
    u_int namelen;
    userspace_pointer_t oldp;
    userspace_pointer_t oldlenp;
    userspace_pointer_t newp;
    size_t newlen;
    errno_t err;
    task_t task;
    ksurface_proc_snapshot_t *proc_snapshot;
} sysctl_req_t;

typedef int (*sysctl_fn_t)(sysctl_req_t *req);

typedef struct {
    const int mib[20];
    size_t mib_len;
    sysctl_fn_t fn;
} sysctl_map_entry_t;

typedef struct {
    const char *name;
    const int mib[6];
    size_t mib_len;
} sysctl_name_map_entry_t;

/* sysctl apis */

int sysctl_kernmaxproc(sysctl_req_t *req)
{
    size_t user_outlen = 0;
    size_t needed = sizeof(int);
    int maxproc = PROC_MAX;
    
    /* if user provided oldlenp, copy it in */
    if(req->oldlenp != NULL &&
       !mach_syscall_copy_in(req->task, sizeof(size_t), &user_outlen, req->oldlenp))
    {
        req->err = EFAULT;
        return -1;
    }
    
    /* if oldp is set user wants the value */
    if(req->oldp)
    {
        /* sanitizing buffer lenght */
        if(user_outlen < needed)
        {
            req->err = ENOMEM;
            return -1;
        }
        
        if(!mach_syscall_copy_out(req->task, sizeof(int), &maxproc, req->oldp))
        {
            req->err = EFAULT;
            return -1;
        }
    }
    
    /* always copy out size */
    if(req->oldlenp != NULL &&
       !mach_syscall_copy_out(req->task, sizeof(size_t), &needed, req->oldlenp))
    {
        req->err = EFAULT;
        return -1;
    }
    
    return 0;
}

int sysctl_kernproc(sysctl_req_t *req)
{
    /* prepare arguments */
    proc_flavour_t flavour;
    size_t user_outlen = 0;
    size_t needed = 0;
    
    /* finding out flavour */
    switch(req->name[2])
    {
        case KERN_PROC_ALL:
            flavour = PROC_FLV_ALL;
            break;
        case KERN_PROC_UID:
            flavour = PROC_FLV_UID;
            goto validate;
        case KERN_PROC_RUID:
            flavour = PROC_FLV_RUID;
            goto validate;
        case KERN_PROC_SESSION:
            flavour = PROC_FLV_SID;
            goto validate;
        case KERN_PROC_PID:
            flavour = PROC_FLV_PID;
            
            /* some flavours require 4 */
        validate:
            if(!req->oldlenp || req->namelen != 4)
            {
                req->err = EINVAL;
                return -1;
            }
            
            break;
        default:
            req->err = EINVAL;
            return -1;
    }
    
    /* if user provided oldlenp, copy it in */
    if(req->oldlenp != NULL &&
       !mach_syscall_copy_in(req->task, sizeof(size_t), &user_outlen, req->oldlenp))
    {
        req->err = EFAULT;
        return -1;
    }
    
    /* copying current process table */
    proc_table_rdlock();
    kinfo_proc_t *kpbuf = NULL;
    ksurface_return_t ksr = proc_list(req->proc_snapshot, &kpbuf, &needed, flavour, req->name[3]);
    proc_table_unlock();
    
    /* checking if succeeded  */
    if(ksr != SURFACE_SUCCESS)
    {
        req->err = ENOMEM;
        goto out_free_kpbuf_and_ret_excp;
    }
    
    /* getting how many processes we currently have */
    if(needed == 0)
    {
        req->err = ENOMEM;
        goto out_free_kpbuf_and_ret_excp;
    }
    
    /* size only query */
    if(req->oldp == NULL)
    {
        if(!mach_syscall_copy_out(req->task, sizeof(size_t), &needed, req->oldlenp))
        {
            req->err = EFAULT;
            goto out_free_kpbuf_and_ret_excp;
        }
        goto out_free_kpbuf;
    }
    
    /* copy request fails (buffer too small) */
    if(user_outlen < needed)
    {
        if(!mach_syscall_copy_out(req->task, sizeof(size_t), &needed, req->oldlenp))
        {
            req->err = EFAULT;
            goto out_free_kpbuf_and_ret_excp;
        }
        req->err = ENOMEM;
        goto out_free_kpbuf_and_ret_excp;
    }
    else
    {
        if(!mach_syscall_copy_out(req->task, needed, kpbuf, req->oldp))
        {
            req->err = EFAULT;
            goto out_free_kpbuf_and_ret_excp;
        }
    }
    
    /* copy out buffer lenght */
    if(!mach_syscall_copy_out(req->task, sizeof(size_t), &needed, req->oldlenp))
    {
        req->err = EFAULT;
        goto out_free_kpbuf_and_ret_excp;
    }
    
out_free_kpbuf:
    free(kpbuf);
    return 0;
    
out_free_kpbuf_and_ret_excp:
    free(kpbuf);
    return -1;
}

bool is_valid_hostname_regex(const char *hostname)
{
    /* checking string lenght */
    if(strnlen(hostname, MAXHOSTNAMELEN) >= MAXHOSTNAMELEN)
    {
        return false;
    }
    
    /* compiling regex pattern once */
    static regex_t *regex;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        /* allocating this, dont make me regret this */
        regex = malloc(sizeof(regex_t));
        
        /* null terminator check */
        if(regex == NULL)
        {
            return;
        }
        
        /* compiling regex pattern */
        if(regcomp(regex, "^([a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?\\.)*[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$", REG_EXTENDED) != 0)
        {
            /* if it fails then freeing regex and setting it to null */
            free(regex);
            regex = NULL;
        }
    });
    
    /* null pointer checking */
    if(regex == NULL)
    {
        return false;
    }
    
    /* the pattern must be valid */
    return (regexec(regex, hostname, 0, NULL, 0) == 0);
}

int sysctl_kernhostname(sysctl_req_t *req)
{
    if(req->oldp && req->oldlenp)
    {
        host_rdlock();
        size_t hlen = strlen(ksurface->host_info.hostname) + 1;
        
        size_t oldlenp = 0;
        if(!mach_syscall_copy_in(req->task, sizeof(size_t), &oldlenp, req->oldlenp))
        {
            req->err = EFAULT;
            host_unlock();
            return -1;
        }
        
        if(oldlenp < hlen) { req->err = ENOMEM; return -1; }
        
        if(!mach_syscall_copy_out(req->task, hlen, ksurface->host_info.hostname, req->oldp) ||
           !mach_syscall_copy_out(req->task, sizeof(size_t), &hlen, req->oldlenp))
        {
            req->err = EFAULT;
            host_unlock();
            return -1;
        }
        host_unlock();
    }
    
    if(req->newp && req->newlen)
    {
        if(!entitlement_got_entitlement(proc_getentitlements(req->proc_snapshot), PEEntitlementHostManager))
        {
            req->err = EPERM;
            return -1;
        }
        
        if(req->newlen > MAXHOSTNAMELEN)
        {
            req->err = EINVAL;
            return -1;
        }
        
        /* copy buffer in */
        char *newname = mach_syscall_alloc_in(req->task, req->newlen, req->newp);
        if(!newname)
        {
            req->err = EFAULT;
            return -1;
        }
        
        /* checking regex */
        if(!is_valid_hostname_regex(newname))
        {
            req->err = EINVAL;
            free(newname);
            return -1;
        }
        
        host_wrlock();
        strlcpy(ksurface->host_info.hostname, newname, req->newlen + 1);
        [[NSUserDefaults standardUserDefaults] setObject:[NSString stringWithCString:ksurface->host_info.hostname encoding:NSUTF8StringEncoding] forKey:@"LDEHostname"];
        host_unlock();
        
        free(newname);
    }
    
    return 0;
}

/* sysctl map entries */
static const sysctl_map_entry_t sysctl_map[] = {
    { { CTL_KERN, KERN_HOSTNAME                 }, 2, sysctl_kernhostname },
    { { CTL_KERN, KERN_MAXPROC                  }, 2, sysctl_kernmaxproc },
    { { CTL_KERN, KERN_PROC, KERN_PROC_ALL      }, 3, sysctl_kernproc },
    { { CTL_KERN, KERN_PROC, KERN_PROC_SESSION  }, 3, sysctl_kernproc },
    { { CTL_KERN, KERN_PROC, KERN_PROC_PID      }, 3, sysctl_kernproc },
    { { CTL_KERN, KERN_PROC, KERN_PROC_UID      }, 3, sysctl_kernproc },
    { { CTL_KERN, KERN_PROC, KERN_PROC_RUID     }, 3, sysctl_kernproc },
};

static const sysctl_name_map_entry_t sysctl_name_map[] = {
    { "kern.hostname",          { CTL_KERN, KERN_HOSTNAME                }, 2 },
    { "kern.maxproc",           { CTL_KERN, KERN_MAXPROC                 }, 2 },
    { "kern.proc.all",          { CTL_KERN, KERN_PROC, KERN_PROC_ALL     }, 3 },
};

/* lookup symbol */
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

DEFINE_SYSCALL_HANDLER(sysctl)
{
    sys_name("SYS_sysctl");
    
    /* prepare request */
    sysctl_req_t req = {
        .name           = {},
        .namelen        = (u_int)args[1],
        .oldp           = (userspace_pointer_t)args[2],
        .oldlenp        = (userspace_pointer_t)args[3],
        .newp           = (userspace_pointer_t)args[4],
        .newlen         = (size_t)args[5],
        .err            = 0,
        .task           = task,
        .proc_snapshot  = sys_proc_snapshot_,
    };
    
    size_t count = req.namelen;
    
    /* maximum items are 20 so sanity checking */
    if(count > 20)
    {
        sys_return_failure(E2BIG);
    }
    
    /* copy name array from userspace */
    if(!mach_syscall_copy_in(task, count * sizeof(int), &(req.name), (userspace_pointer_t)args[0]))
    {
        sys_return_failure(EFAULT);
    }
    
    /* looking up sysctl map */
    sysctl_fn_t fn = sysctl_lookup(&req);
    if(fn != NULL)
    {
        int ret = fn(&req);
        *err = req.err;
        return ret;
    }
    
    sys_return_failure(ENOSYS);
}

DEFINE_SYSCALL_HANDLER(sysctlbyname)
{
    sys_name("SYS_sysctlbyname");
    
    char *name_buf = mach_syscall_copy_str_in(task, (userspace_pointer_t)args[0], 128);
    
    if(name_buf == NULL)
    {
        sys_return_failure(EINVAL);
    }
    
    const sysctl_name_map_entry_t *found = NULL;
    for(size_t i = 0; i < sizeof(sysctl_name_map)/sizeof(sysctl_name_map[0]); i++)
    {
        if(strcmp(name_buf, sysctl_name_map[i].name) == 0)
        {
            found = &sysctl_name_map[i];
            break;
        }
    }
    
    free(name_buf);
    
    if(found == NULL)
    {
        sys_return_failure(ENOSYS);
    }
    
    sysctl_req_t req = {
        .name           = {},
        .namelen        = (u_int)found->mib_len,
        .oldp           = (userspace_pointer_t)args[1],
        .oldlenp        = (userspace_pointer_t)args[2],
        .newp           = (userspace_pointer_t)args[3],
        .newlen         = (size_t)args[4],
        .err            = 0,
        .task           = task,
        .proc_snapshot  = sys_proc_snapshot_,
    };
    
    memcpy(req.name, found->mib, found->mib_len * sizeof(int));
    
    sysctl_fn_t fn = sysctl_lookup(&req);
    if(fn != NULL)
    {
        int ret = fn(&req);
        *err = req.err;
        return ret;
    }
    
    sys_return_failure(ENOSYS);
}
