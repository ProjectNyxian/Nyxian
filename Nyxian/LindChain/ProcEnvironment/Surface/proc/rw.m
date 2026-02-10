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

#import <LindChain/ProcEnvironment/Surface/proc/rw.h>

void proc_read_lock(ksurface_proc_t *proc)
{
    if(proc == NULL)
    {
        return;
    }
    
    pthread_rwlock_rdlock(&(proc->header.rwlock));
}

void proc_write_lock(ksurface_proc_t *proc)
{
    if(proc == NULL)
    {
        return;
    }
    
    pthread_rwlock_wrlock(&(proc->header.rwlock));
}

void proc_unlock(ksurface_proc_t *proc)
{
    if(proc == NULL)
    {
        return;
    }
    
    pthread_rwlock_unlock(&(proc->header.rwlock));
}

void proc_table_read_lock(void)
{
    if(ksurface == NULL)
    {
        return;
    }
    
    pthread_rwlock_rdlock(&(ksurface->proc_info.struct_lock));
}

void proc_table_write_lock(void)
{
    if(ksurface == NULL)
    {
        return;
    }
    
    pthread_rwlock_wrlock(&(ksurface->proc_info.struct_lock));
}

void proc_table_unlock(void)
{
    if(ksurface == NULL)
    {
        return;
    }
    
    pthread_rwlock_unlock(&(ksurface->proc_info.struct_lock));
}

void host_read_lock(void)
{
    if(ksurface == NULL)
    {
        return;
    }
    
    pthread_rwlock_rdlock(&(ksurface->host_info.struct_lock));
}

void host_write_lock(void)
{
    if(ksurface == NULL)
    {
        return;
    }
    
    pthread_rwlock_wrlock(&(ksurface->host_info.struct_lock));
}

void host_unlock(void)
{
    if(ksurface == NULL)
    {
        return;
    }
    
    pthread_rwlock_unlock(&(ksurface->host_info.struct_lock));
}

void proc_task_read_lock(void)
{
    if(ksurface == NULL)
    {
        return;
    }
    
    pthread_rwlock_rdlock(&(ksurface->proc_info.task_lock));
}

void proc_task_write_lock(void)
{
    if(ksurface == NULL)
    {
        return;
    }
    
    pthread_rwlock_wrlock(&(ksurface->proc_info.task_lock));
}

void proc_task_unlock(void)
{
    if(ksurface == NULL)
    {
        return;
    }
    
    pthread_rwlock_unlock(&(ksurface->proc_info.task_lock));
}
