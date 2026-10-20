/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2025 - 2026 emexlab

 This file is part of Nyxian.

 Licensed under the emexLabs Public Source License, version 1.1
 (EPSL 1.1).

 Private use and modification are permitted under the license.
 Redistribution of source or binaries, modified or unmodified,
 requires prior written permission from emexLabs.

 External deployment is subject to the source-availability
 requirements and other conditions of the license.

 Provided "AS IS", without warranty, to the extent permitted by law.

 See LICENSE for the full license terms.
*/

#include <LindChain/ProcEnvironment/Surface/libkern/klog.h>
#include <LindChain/ProcEnvironment/Surface/proc/proc.h>
#include <ksurface_config.h>
#include <mach/mach_time.h>

DEFINE_KVOBJECT_MAIN_EVENT_HANDLER(proc)
{
    /* handle size request */
    if(kvarr == NULL)
    {
        return (int64_t)sizeof(ksurface_proc_t);
    }
    
    /* get our kobj */
    ksurface_proc_t *proc = (ksurface_proc_t*)kvarr[0];
    
    switch(type)
    {
        case kvObjEventInit:
        {
            klog_log("ksurface:proc:init", "initializing process @ %p", proc);
            
            /* setting fresh properties */
            proc->bsd.kp_eproc.e_ucred.cr_ngroups = 1;
            proc->bsd.kp_proc.p_priority = PUSER;
            proc->bsd.kp_proc.p_usrpri = PUSER;
            proc->bsd.kp_eproc.e_tdev = -1;
            proc->bsd.kp_eproc.e_flag = 2;
            proc->nyx.login_name[0] = '\0';
            proc->nyx.login_name_len = 0;
            proc->nyx.supplementary_group_count = 0;
            
            proc_setmobilecred(proc);
            
            goto mutual_init;
        }
        case kvObjEventCopy:
        {
            ksurface_proc_t *src = (ksurface_proc_t*)kvarr[1];
            
            klog_log("ksurface:proc:copy", "copying process @ %p from process @ %p", proc, src);
            klog_log("ksurface:proc:init", "initializing process @ %p", proc);
            
            /* copy the object into the other object */
            memcpy(&(proc->bsd), &(src->bsd), sizeof(kinfo_proc_t));
            memcpy(&(proc->nyx), &(src->nyx), sizeof(knyx_proc_t));
            
        mutual_init:
            proc->bsd.kp_proc.p_stat = SRUN;
            proc->bsd.kp_proc.p_flag = P_LP64 | P_EXEC;
            proc->nyx.p_status = W_EXITCODE(0, SIGKILL);
            
            if(gettimeofday(&proc->bsd.kp_proc.p_un.__p_starttime, NULL) != 0)
            {
                return -1;
            }
            proc->nyx.start_abstime = mach_absolute_time();
            
            if(pthread_mutex_init(&(proc->children.mutex), NULL) != 0)
            {
                return -1;
            }
            
            return 0;
        }
        case kvObjEventSnapshot:
        {
            ksurface_proc_t *src = (ksurface_proc_t*)kvarr[1];
            
            /* copy the object into the other object */
            memcpy(&(proc->bsd), &(src->bsd), sizeof(kinfo_proc_t));
            memcpy(&(proc->nyx), &(src->nyx), sizeof(knyx_proc_t));
            
            return 0;
        }
        case kvObjEventDeinit:
            if(proc->header.base_type != kvObjBaseTypeObjectSnapshot)
            {
                klog_log("ksurface:proc:deinit", "deinitializing process @ %p", proc);
                pthread_mutex_destroy(&(proc->children.mutex));
                
                if(proc->task != MACH_PORT_NULL)
                {
                    mach_port_deallocate(mach_task_self(), proc->task);
                }
            }
            trust_identity_destroy(proc->nyx.identity);
            
            /* fallthrough */
        default:
            return 0;
    }
}
