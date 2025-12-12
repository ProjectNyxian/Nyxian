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
#import <LindChain/ProcEnvironment/proxy.h>
#include <errno.h>

enum SYS_PROC_FLAVOUR {
    SYS_PROC_FLAVOUR_ALL = 0,
    SYS_PROC_FLAVOUR_UID = 1,
    SYS_PROC_FLAVOUR_RUID = 2
};

static inline uint32_t sysctl_proc_buf_helper_cnt(kinfo_proc_t *pt,
                                                  uint32_t pt_cnt,
                                                  int flavour,
                                                  uid_t uid)
{
    uint32_t count = 0;
    switch(flavour)
    {
        case SYS_PROC_FLAVOUR_ALL:
            count = pt_cnt;
            break;
        case SYS_PROC_FLAVOUR_UID:
        {
            for(uint32_t i = 0; i < pt_cnt; i++)
            {
                if(pt[i].kp_eproc.e_ucred.cr_uid == uid)
                {
                    count++;
                }
            }
            break;
        }
        case SYS_PROC_FLAVOUR_RUID:
        {
            for(uint32_t i = 0; i < pt_cnt; i++)
            {
                if(pt[i].kp_eproc.e_pcred.p_ruid == uid)
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

static inline size_t sysctl_proc_buf_helper_cpy(kinfo_proc_t *pt,
                                                uint32_t pt_cnt,
                                                int flavour,
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
            for(uint32_t i = 0; i < pt_cnt && written_structures < pt_cnt; i++)
            {
                memcpy(&kprocs[written_structures++], &pt[i], sizeof(kinfo_proc_t));
            }
            break;
        }
        case SYS_PROC_FLAVOUR_UID:
        {
            for(uint32_t i = 0; i < pt_cnt; i++)
            {
                if(pt[i].kp_eproc.e_ucred.cr_uid == uid)
                {
                    memcpy(&kprocs[written_structures++], &pt[i], sizeof(kinfo_proc_t));
                }
            }
            break;
        }
        case SYS_PROC_FLAVOUR_RUID:
        {
            for(uint32_t i = 0; i < pt_cnt; i++)
            {
                if(pt[i].kp_eproc.e_pcred.p_ruid == uid)
                {
                    memcpy(&kprocs[written_structures++], &pt[i], sizeof(kinfo_proc_t));
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
    kinfo_proc_t *pt = NULL;
    uint32_t pt_cnt = 0;
    environment_proxy_getproctable(&pt, &pt_cnt);
    if(pt == NULL)
    {
        errno = EACCES;
        return -1;
    }
    
    size_t needed_bytes = 0;
    
    // Sequence
    uint32_t count = sysctl_proc_buf_helper_cnt(pt, pt_cnt, flavour, uid);
    needed_bytes = (size_t)count * sizeof(struct kinfo_proc);
    
    if(needed_out)
        *needed_out = needed_bytes;
    
    if(buffer == NULL || buffersize == 0)
    {
        return (int)needed_bytes;
    }
    
    if(buffersize < needed_bytes)
    {
        errno = ENOMEM;
        return -1;
    }
    
    return (int)sysctl_proc_buf_helper_cpy(pt, pt_cnt, flavour, uid, buffer, count);
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
    /*if(!req->oldlenp)
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
    }*/

    //pid_t pid = req->name[3];

    // TODO: Fix this
    /*ksurface_proc_t proc;
    ksurface_error_t error = proc_for_pid(pid, &proc);
    if(error != kSurfaceErrorSuccess)
    {
        return -1;
    }

    memcpy(req->oldp, &(proc.bsd), needed);*/
    //*req->oldlenp = needed;

    errno = ENOSYS;
    return -1;
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
