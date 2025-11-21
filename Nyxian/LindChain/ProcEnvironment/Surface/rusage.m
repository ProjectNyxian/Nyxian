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

#import <LindChain/LiveContainer/Tweaks/libproc.h>
#import <LindChain/ProcEnvironment/Surface/surface.h>
#import <LindChain/ProcEnvironment/libproc.h>
#import <LindChain/ProcEnvironment/tfp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/sysctl.h>
#include <mach/mach.h>

int proc_libproc_pid_rusage(pid_t pid,
                            int flavor,
                            struct rusage_info_v2 *ri)
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
        
        struct proc_taskallinfo tai;
        if(proc_libproc_pidinfo(pid, PROC_PIDTASKALLINFO, 0, &tai, sizeof(tai)) == sizeof(tai))
        {
            ri->ri_proc_start_abstime = tai.pbsd.pbi_start_tvsec * NSEC_PER_SEC +
            tai.pbsd.pbi_start_tvusec * NSEC_PER_USEC;
        }
        
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
