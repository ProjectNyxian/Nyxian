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
#import <LindChain/ProcEnvironment/Surface/surface.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#include <errno.h>

/*enum SYS_PROC_FLAVOUR {
    SYS_PROC_FLAVOUR_ALL = 0,
    SYS_PROC_FLAVOUR_UID = 1,
    SYS_PROC_FLAVOUR_RUID = 2
};

static inline uint32_t sysctl_proc_buf_helper_cnt(int flavour,
                                                  uid_t uid)
{
    uint32_t count = 0;
    switch(flavour)
    {
        case SYS_PROC_FLAVOUR_ALL:
            count = surface->proc_info.proc_count;
            break;
        case SYS_PROC_FLAVOUR_UID:
        {
            for(uint32_t i = 0; i < surface->proc_info.proc_count; i++)
            {
                if(proc_getuid(surface->proc_info.proc[i]) == uid)
                {
                    count++;
                }
            }
            break;
        }
        case SYS_PROC_FLAVOUR_RUID:
        {
            for(uint32_t i = 0; i < surface->proc_info.proc_count; i++)
            {
                if(proc_getruid(surface->proc_info.proc[i]) == uid)
                {
                    count++;
                }
            }
            break;
        }
        default:
            break;
    }
    return count;
}

static inline size_t sysctl_proc_buf_helper_cpy(int flavour,
                                                uid_t uid,
                                                void *buffer,
                                                uint32_t count)
{
    struct kinfo_proc *kprocs = buffer;
    size_t written_structures = 0;
    
    switch(flavour)
    {
        case SYS_PROC_FLAVOUR_ALL:
        {
            for(uint32_t i = 0; i < surface->proc_info.proc_count && written_structures < count; i++)
            {
                memset(&kprocs[i], 0, sizeof(kinfo_proc_t));
                memcpy(&kprocs[i], &surface->proc_info.proc[i].bsd, sizeof(struct kinfo_proc));
                written_structures++;
            }
            break;
        }
        case SYS_PROC_FLAVOUR_UID:
        {
            for(uint32_t i = 0; i < surface->proc_info.proc_count && written_structures < count; i++)
            {
                if(proc_getuid(surface->proc_info.proc[i]) == uid)
                {
                    memcpy(&kprocs[written_structures++], &surface->proc_info.proc[i].bsd, sizeof(kinfo_proc_t));
                }
            }
            break;
        }
        case SYS_PROC_FLAVOUR_RUID:
        {
            for(uint32_t i = 0; i < surface->proc_info.proc_count && written_structures < count; i++)
            {
                if(proc_getruid(surface->proc_info.proc[i]) == uid)
                {
                    memcpy(&kprocs[written_structures++], &surface->proc_info.proc[i].bsd, sizeof(kinfo_proc_t));
                }
            }
            break;
        }
        default:
            return 0;
    }
    
    return (written_structures * sizeof(kinfo_proc_t));
}

static inline int sysctl_proc_buf_helper(void *buffer,
                                         size_t buffersize,
                                         size_t *needed_out,
                                         int flavour,
                                         uid_t uid)
{
    // Dont use if uninitilized
    if(surface == NULL) return 0;
    
    size_t needed_bytes = 0;
    int ret = 0;
    
    // Sequence
    unsigned long seq;
    
    do {
        seq = reflock_read_begin(&(surface->reflock));
        
        uint32_t count = sysctl_proc_buf_helper_cnt(flavour, uid);
        needed_bytes = (size_t)count * sizeof(struct kinfo_proc);
        
        if(needed_out)
            *needed_out = needed_bytes;
        
        if(buffer == NULL || buffersize == 0)
        {
            ret = (int)needed_bytes;
            break;
        }
        
        if(buffersize < needed_bytes)
        {
            errno = ENOMEM;
            ret = -1;
            break;
        }
        
        ret = (int)sysctl_proc_buf_helper_cpy(flavour, uid, buffer, count);
    }
    while(reflock_read_retry(&(surface->reflock), seq));
    
    return ret;
}

int sysctl_kernprocall(sysctl_req_t *req)
{
    if(!req->oldlenp)
    {
        errno = EINVAL;
        return -1;
    }
    
    size_t needed = sysctl_proc_buf_helper(NULL, 0, NULL, SYS_PROC_FLAVOUR_ALL, 0);
    
    if(req->oldp == NULL || *(req->oldlenp) == 0)
    {
        *(req->oldlenp) = needed;
        return 0;
    }
    
    if(*(req->oldlenp) < needed)
    {
        *(req->oldlenp) = needed;
        errno = ENOMEM;
        return -1;
    }
    
    int written = sysctl_proc_buf_helper(req->oldp, *(req->oldlenp), NULL, SYS_PROC_FLAVOUR_ALL, 0);
    if(written < 0) return -1;
    
    *(req->oldlenp) = written;
    return 0;
}

int sysctl_kernprocpid(sysctl_req_t *req)
{
    if(!req->oldlenp)
    {
        errno = EINVAL;
        return -1;
    }

    size_t needed = sizeof(kinfo_proc_t);

    if(req->namelen == 3)
    {
        *req->oldlenp = needed;
        return 0;
    }

    if(req->namelen != 4)
    {
        errno = EINVAL;
        return -1;
    }

    if(req->oldp == NULL || *req->oldlenp == 0)
    {
        *req->oldlenp = needed;
        return 0;
    }

    if(*req->oldlenp < needed)
    {
        *req->oldlenp = needed;
        errno = ENOMEM;
        return -1;
    }

    pid_t pid = req->name[3];

    ksurface_proc_t proc;
    ksurface_error_t error = proc_for_pid(pid, &proc);
    if(error != kSurfaceErrorSuccess)
    {
        return -1;
    }

    memcpy(req->oldp, &(proc.bsd), needed);
    *req->oldlenp = needed;

    return 0;
}

int sysctl_kernprocuid(sysctl_req_t *req)
{
    if(!req->oldlenp || req->namelen != 4)
    {
        errno = EINVAL;
        return -1;
    }
    
    size_t needed = sysctl_proc_buf_helper(NULL, 0, NULL, SYS_PROC_FLAVOUR_UID, req->name[3]);
    
    if(req->oldp == NULL || *(req->oldlenp) == 0)
    {
        *(req->oldlenp) = needed;
        return 0;
    }
    
    if(*(req->oldlenp) < needed)
    {
        *(req->oldlenp) = needed;
        errno = ENOMEM;
        return -1;
    }
    
    int written = sysctl_proc_buf_helper(req->oldp, *(req->oldlenp), NULL, SYS_PROC_FLAVOUR_UID, req->name[3]);
    if(written < 0) return -1;
    
    *(req->oldlenp) = written;
    return 0;
}

int sysctl_kernprocruid(sysctl_req_t *req)
{
    if(!req->oldlenp || req->namelen != 4)
    {
        errno = EINVAL;
        return -1;
    }
    
    size_t needed = sysctl_proc_buf_helper(NULL, 0, NULL, SYS_PROC_FLAVOUR_RUID, req->name[3]);
    
    if(req->oldp == NULL || *(req->oldlenp) == 0)
    {
        *(req->oldlenp) = needed;
        return 0;
    }
    
    if(*(req->oldlenp) < needed)
    {
        *(req->oldlenp) = needed;
        errno = ENOMEM;
        return -1;
    }
    
    int written = sysctl_proc_buf_helper(req->oldp, *(req->oldlenp), NULL, SYS_PROC_FLAVOUR_RUID, req->name[3]);
    if(written < 0) return -1;
    
    *(req->oldlenp) = written;
    return 0;
}
*/
