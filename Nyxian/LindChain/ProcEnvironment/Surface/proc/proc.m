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

#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/Utils/klog.h>

ksurface_proc_t *kernel_proc(void)
{
    return kernel_proc_;
}

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
            /* nullify */
            kv_content_zero(proc);
            
            /* setting fresh properties */
            proc->bsd.kp_eproc.e_ucred.cr_ngroups = 1;
            proc->bsd.kp_proc.p_priority = PUSER;
            proc->bsd.kp_proc.p_usrpri = PUSER;
            proc->bsd.kp_eproc.e_tdev = -1;
            proc->bsd.kp_eproc.e_flag = 2;
            proc->bsd.kp_proc.p_stat = SRUN;
            proc->bsd.kp_proc.p_flag = P_LP64 | P_EXEC;
            proc->nyx.ret = 0;
            proc->nyx.p_stop_reported = 0;
            
            goto mutual_init;
        }
        case kvObjEventCopy:
        {
            ksurface_proc_t *src = (ksurface_proc_t*)kvarr[1];
            
            /* copy the object into the other object */
            kv_content_zero(proc);
            memcpy(&(proc->bsd), &(src->bsd), sizeof(kinfo_proc_t));
            memcpy(&(proc->nyx), &(src->nyx), sizeof(knyx_proc_t));
            
            proc->bsd.kp_proc.p_stat = SRUN;
            proc->bsd.kp_proc.p_flag = P_LP64 | P_EXEC;
            proc->nyx.p_stop_reported = 0;
            
        mutual_init:
            if(gettimeofday(&proc->bsd.kp_proc.p_un.__p_starttime, NULL) != 0)
            {
                return -1;
            }
            
            pthread_mutex_init(&(proc->children.mutex), NULL);
            
            return 0;
        }
        case kvObjEventSnapshot:
        {
            ksurface_proc_t *src = (ksurface_proc_t*)kvarr[1];
            
            /* copy the object into the other object */
            kv_content_zero(proc);
            memcpy(&(proc->bsd), &(src->bsd), sizeof(kinfo_proc_t));
            memcpy(&(proc->nyx), &(src->nyx), sizeof(knyx_proc_t));
            
            if(src->task != MACH_PORT_NULL)
            {
                kern_return_t kr = mach_port_mod_refs(mach_task_self(), src->task, MACH_PORT_RIGHT_SEND, 1);
                
                /* dont allow us to loose the send right to the task port */
                if(kr != KERN_SUCCESS)
                {
                    return -1;
                }
                
                proc->task = src->task;
            }
            
            /* done */
            return 0;
        }
        case kvObjEventDeinit:
            if(proc->header.base_type != kvObjBaseTypeObjectSnapshot)
            {
                klog_log(@"proc:deinit", @"deinitilizing process @ %p", proc);
                pthread_mutex_destroy(&(proc->children.mutex));
            }
            
            if(proc->task != MACH_PORT_NULL)
            {
                mach_port_deallocate(mach_task_self(), proc->task);
            }
            
            /* fallthrough */
        default:
            return 0;
    }
}
