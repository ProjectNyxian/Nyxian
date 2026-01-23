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

#import <Foundation/Foundation.h>
#import <LindChain/ProcEnvironment/environment.h>
#import <LindChain/ProcEnvironment/syscall.h>
#import <LindChain/ProcEnvironment/proxy.h>
#import <LindChain/ProcEnvironment/libproc.h>
#import <LindChain/litehook/litehook.h>
#import <LindChain/LiveContainer/Tweaks/libproc.h>
#import <LindChain/ProcEnvironment/Surface/surface.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>

/*int proc_libproc_listallpids(void *buffer,
                             int buffersize)
{
    if(buffersize < 0)
    {
        errno = EINVAL;
        return -1;
    }
    
    size_t n = 0;
    size_t needed_bytes = 0;

    unsigned long seq;
    
    do
    {
        seq = reflock_read_begin(&(surface->reflock));

        uint32_t count = surface->proc_info.proc_count;
        needed_bytes = (size_t)count * sizeof(pid_t);

        if (buffer != NULL && buffersize > 0) {
            size_t capacity = (size_t)buffersize / sizeof(pid_t);
            n = count < capacity ? count : capacity;

            pid_t *pids = (pid_t *)buffer;
            for (size_t i = 0; i < n; i++) {
                pids[i] = surface->proc_info.proc[i].bsd.kp_proc.p_pid;
            }
        }

    }
    while (reflock_read_retry(&(surface->reflock), seq));
    
    if(buffer == NULL || buffersize == 0)
    {
        return (int)needed_bytes;
    }
    
    return (int)(n * sizeof(pid_t));
}

int proc_libproc_name(pid_t pid,
                      void * buffer,
                      uint32_t buffersize)
{
    if(buffersize == 0 || buffer == NULL)
    {
        return 0;
    }
    
    ksurface_proc_t proc = {};
    ksurface_error_t error = proc_for_pid(pid, &proc);
    if(error != kSurfaceErrorSuccess)
    {
        return 0;
    }
        
    strlcpy((char*)buffer, proc.bsd.kp_proc.p_comm, buffersize);
    
    return (int)strlen((char*)buffer);
}*/

DEFINE_HOOK(proc_pidpath, int, (pid_t pid,
                                void * buffer,
                                uint32_t buffersize))
{
    if(buffersize == 0 || buffer == NULL)
    {
        return 0;
    }
    
    knyx_proc_t nyx = environment_proxy_nyxcopy(pid);

    strlcpy((char*)buffer, nyx.executable_path, buffersize);
    return (int)strlen((char*)buffer);
}

/*int proc_libproc_pidinfo(pid_t pid,
                         int flavor,
                         uint64_t arg,
                         void * buffer,
                         int buffersize)
{
    if(buffer == NULL || buffersize <= 0)
    {
        return 0;
    }
    
    ksurface_proc_t proc = {};
    ksurface_error_t error = proc_for_pid(pid, &proc);
    if(error != kSurfaceErrorSuccess)
    {
        return 0;
    }

    switch(flavor)
    {
        case PROC_PIDTASKINFO:
            memset(buffer, 0, buffersize);
            return sizeof(struct proc_taskinfo);
        case PROC_PIDTASKALLINFO: {
            if(buffersize < sizeof(struct proc_taskallinfo))
            {
                return 0;
            }
            struct proc_taskallinfo *info = (struct proc_taskallinfo*)buffer;
            memset(info, 0, sizeof(*info));
            memcpy(&info->pbsd, &proc.bsd, sizeof(proc.bsd) < sizeof(info->pbsd) ? sizeof(proc.bsd) : sizeof(info->pbsd));
            return sizeof(struct proc_taskallinfo);
    }

    default:
        errno = ENOTSUP;
        return 0;
    }
}*/

DEFINE_HOOK(proc_pid_rusage, int, (pid_t pid,
                                           int flavor,
                                           struct rusage_info_v2 *ri))
{
    if(environment_supports_tfp())
    {
        if (!ri) return -1;
        memset(ri, 0, sizeof(*ri));
        
        task_t task;
        kern_return_t kr = environment_task_for_pid(mach_task_self(), pid, &task);
        if(kr != KERN_SUCCESS) return EPERM;
        
        struct task_absolutetime_info tai2;
        mach_msg_type_number_t count = TASK_ABSOLUTETIME_INFO_COUNT;
        if(task_info(task, TASK_ABSOLUTETIME_INFO, (task_info_t)&tai2, &count) == KERN_SUCCESS)
        {
            mach_timebase_info_data_t timebase;
            mach_timebase_info(&timebase);

            uint64_t user_ns   = (tai2.total_user   * timebase.numer) / timebase.denom;
            uint64_t system_ns = (tai2.total_system * timebase.numer) / timebase.denom;

            ri->ri_user_time   = user_ns;
            ri->ri_system_time = system_ns;
        }

        struct task_basic_info_64 tbi;
        count = TASK_BASIC_INFO_64_COUNT;
        if(task_info(task, TASK_BASIC_INFO_64, (task_info_t)&tbi, &count) == KERN_SUCCESS)
        {
            ri->ri_resident_size = tbi.resident_size;
            ri->ri_wired_size    = tbi.resident_size;
        }
        
        struct task_vm_info vmi;
        count = TASK_VM_INFO_COUNT;
        if(task_info(task, TASK_VM_INFO, (task_info_t)&vmi, &count) == KERN_SUCCESS)
        {
            ri->ri_phys_footprint = vmi.phys_footprint;
        }
        
        struct task_events_info tei;
        count = TASK_EVENTS_INFO_COUNT;
        if(task_info(task, TASK_EVENTS_INFO, (task_info_t)&tei, &count) == KERN_SUCCESS)
        {
            ri->ri_pageins = tei.pageins;
        }
        
        /*struct proc_taskallinfo tai;
        if(proc_libproc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, &tai, sizeof(tai)) == sizeof(tai))
        {
            ri->ri_proc_start_abstime = tai.pbsd.pbi_start_tvsec * NSEC_PER_SEC +
            tai.pbsd.pbi_start_tvusec * NSEC_PER_USEC;
        }*/
        
        struct task_power_info tpi;
        count = TASK_POWER_INFO_COUNT;
        if(task_info(task, TASK_POWER_INFO, (task_info_t)&tpi, &count) == KERN_SUCCESS)
        {
            ri->ri_pkg_idle_wkups   = tpi.task_timer_wakeups_bin_1;
            ri->ri_interrupt_wkups  = tpi.task_interrupt_wakeups;
        }
        
        mach_port_deallocate(mach_task_self(), task);
    }
    return 0;
}


DEFINE_HOOK(kill, int, (pid_t pid, int sig))
{
    return (int)environment_syscall(SYS_KILL, pid, sig);
}

void environment_libproc_init(void)
{
    if(environment_is_role(EnvironmentRoleGuest))
    {
        DO_HOOK_GLOBAL(proc_pidpath);
        DO_HOOK_GLOBAL(proc_pid_rusage);
        DO_HOOK_GLOBAL(kill);
    }
}
