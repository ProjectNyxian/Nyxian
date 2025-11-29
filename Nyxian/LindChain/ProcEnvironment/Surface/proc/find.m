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

#import <LindChain/ProcEnvironment/Surface/proc/reference.h>
#import <LindChain/ProcEnvironment/Surface/proc/find.h>

ksurface_proc_t *proc_for_pid(pid_t pid)
{
    if(ksurface == NULL) return NULL;
    ksurface_proc_t *proc = NULL;
    rcu_read_lock(&(ksurface->proc_info.rcu));
    uint32_t count = atomic_load(&(ksurface->proc_info.proc_count));
    for(uint32_t i = 0; i < count; i++)
    {
        ksurface_proc_t *p = rcu_dereference(ksurface->proc_info.proc[i]);
        if(p != NULL && p->bsd.kp_proc.p_pid == pid && !atomic_load(&p->dead))
        {
            if(proc_retain(p))
            {
                if(p->bsd.kp_proc.p_pid == pid)
                {
                    proc = p;
                }
                else
                {
                    proc_release(p);
                }
            }
            break;
        }
    }
    rcu_read_unlock(&(ksurface->proc_info.rcu));
    return proc;
}

ksurface_proc_t *proc_for_pid_unsafe(pid_t pid)
{
    if(ksurface == NULL) return NULL;
    ksurface_proc_t *proc = NULL;
    for(unsigned long i = 0; i < ksurface->proc_info.proc_count; i++)
    {
        ksurface_proc_t *p = rcu_dereference(ksurface->proc_info.proc[i]);
        if(p != NULL && p->bsd.kp_proc.p_pid == pid)
        {
            proc = p;
            break;
        }
    }
    return proc;
}
