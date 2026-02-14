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

ksurface_proc_t *kernel_proc(void)
{
    return kernel_proc_;
}

DEFINE_KVOBJECT_INIT_HANDLER(proc)
{
    ksurface_proc_t *proc = (ksurface_proc_t*)kvo;
    
    if(src != NULL)
    {
        /* copy it! */
        memcpy(&(proc->kproc.kcproc), &(((ksurface_proc_t*)src)->kproc.kcproc), sizeof(ksurface_kcproc_t));
    }
    else
    {
        /* nullify */
        memset(&(proc->kproc), 0, sizeof(ksurface_kproc_t));
        
        /* setting fresh properties */
        proc->kproc.kcproc.bsd.kp_eproc.e_ucred.cr_ngroups = 1;
        proc->kproc.kcproc.bsd.kp_proc.p_priority = PUSER;
        proc->kproc.kcproc.bsd.kp_proc.p_usrpri = PUSER;
        proc->kproc.kcproc.bsd.kp_eproc.e_tdev = -1;
        proc->kproc.kcproc.bsd.kp_eproc.e_flag = 2;
        proc->kproc.kcproc.bsd.kp_proc.p_stat = SRUN;
        proc->kproc.kcproc.bsd.kp_proc.p_flag = P_LP64 | P_EXEC;
        proc->kproc.kcproc.nyx.sid = 0;
    }
    
    pthread_mutex_init(&(proc->kproc.children.mutex), NULL);
    gettimeofday(&proc->kproc.kcproc.bsd.kp_proc.p_un.__p_starttime, NULL);
}

DEFINE_KVOBJECT_DEINIT_HANDLER(proc)
{
    ksurface_proc_t *proc = (ksurface_proc_t*)kvo;
    
    pthread_mutex_destroy(&(proc->kproc.children.mutex));
    
    task_wrlock();
    
    /* deallocate those dead ports */
    if(proc->kproc.task != MACH_PORT_NULL)
    {
        mach_port_deallocate(mach_task_self(), proc->kproc.task);
    }
    
    if(proc->kproc.eport != MACH_PORT_NULL)
    {
        mach_port_deallocate(mach_task_self(), proc->kproc.task);
    }
    
    task_unlock();
}
