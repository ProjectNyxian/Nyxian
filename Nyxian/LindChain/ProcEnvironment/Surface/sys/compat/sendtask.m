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

#import <LindChain/ProcEnvironment/Surface/sys/compat/sendtask.h>
#import <LindChain/ProcEnvironment/tfp.h>
#import <LindChain/ProcEnvironment/Surface/proc/def.h>
#import <LindChain/ProcEnvironment/Surface/proc/copy.h>
#import <LindChain/ProcEnvironment/Surface/proc/rw.h>

DEFINE_SYSCALL_HANDLER(sendtask)
{
    /* syscall wrapper */
    sys_name("SYS_sendtask");
    sys_need_in_ports_with_cnt(1);
    
    /* view SYS_gettask note on this */
    proc_task_write_lock();
    
    /* checking if task port was already hand off */
    if(sys_proc_copy_->proc->kproc.task != MACH_PORT_NULL)
    {
        proc_task_unlock();
        sys_return_failure(EINVAL);
    }
    
    /* getting port type */
    mach_port_type_t type;
    kern_return_t kr = mach_port_type(mach_task_self(), in_ports[0], &type);

    /* checking if port is valid in the first place */
    if(kr != KERN_SUCCESS ||
       type == MACH_PORT_TYPE_DEAD_NAME ||
       type == 0)
    {
        /* no rights to the task name? */
        proc_task_unlock();
        sys_return_failure(EINVAL);
    }
    
    /* ontaining task port */
    if(environment_supports_full_tfp())
    {
        /* checking if pid of task port is valid */
        pid_t pid = -1;
        kr = pid_for_task(in_ports[0], &pid);
        if(kr != KERN_SUCCESS ||
           pid != proc_getpid(sys_proc_copy_))
        {
            proc_task_unlock();
            sys_return_failure(EINVAL);
        }
    }
    
    /* setting task */
    sys_proc_copy_->proc->kproc.task = in_ports[0];
    
    /* return with succession */
    proc_task_unlock();
    sys_return;
}
