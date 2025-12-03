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

#import <LindChain/ProcEnvironment/Surface/proc/create.h>
#import <LindChain/ProcEnvironment/Surface/proc/copy.h>
#import <LindChain/ProcEnvironment/Surface/proc/def.h>
#include <stdatomic.h>

static void proc_create_mutual_init(ksurface_proc_t *proc)
{
    /* nullify process structure */
    memset(proc, 0, sizeof(*proc));
    
    /* marking process as referenced once */
    atomic_store(&proc->refcount, 1);
    atomic_store(&proc->dead, false);
    
    /* initilizing rw lock and mutex */
    pthread_rwlock_init(&(proc->rwlock), NULL);
    pthread_mutex_init(&(proc->cld.mutex), NULL);
    
    /* reseting the start time */
    gettimeofday(&proc->bsd.kp_proc.p_un.__p_starttime, NULL);
}

ksurface_proc_t *proc_create(pid_t pid,
                             pid_t ppid,
                             const char *path)
{
    /* allocating process */
    ksurface_proc_t *proc = malloc(sizeof(*proc));
    if(proc == NULL)
    {
        return NULL;
    }
    
    /* initilizing with mutual init */
    proc_create_mutual_init(proc);
    
    /* setting bsd process information that are relevant currently */
    proc_setpid(proc, pid);
    proc_setppid(proc, ppid);
    proc_setentitlements(proc, 0);
    
    /* setting other bsd shit */
    proc->bsd.kp_eproc.e_ucred.cr_groups[0] = 0;
    proc->bsd.kp_eproc.e_ucred.cr_groups[1] = 250;
    proc->bsd.kp_eproc.e_ucred.cr_groups[2] = 286;
    proc->bsd.kp_eproc.e_ucred.cr_groups[3] = 299;
    proc->bsd.kp_eproc.e_ucred.cr_ref = 5;
    proc->bsd.kp_proc.p_priority = PUSER;
    proc->bsd.kp_proc.p_usrpri = PUSER;
    proc->bsd.kp_eproc.e_tdev = -1;
    proc->bsd.kp_eproc.e_flag = 2;
    proc->bsd.kp_proc.p_stat = SRUN;
    proc->bsd.kp_proc.p_flag = P_LP64 | P_EXEC;
    
    if(path)
    {
        strncpy(proc->nyx.executable_path, path, PATH_MAX - 1);
        const char *name = strrchr(path, '/');
        name = name ? name + 1 : path;
        strncpy(proc->bsd.kp_proc.p_comm, name, MAXCOMLEN);
    }
    
    return proc;
}

ksurface_proc_t *proc_create_from_proc_copy(ksurface_proc_copy_t *proc_copy)
{
    /* null pointer check */
    if(proc_copy == NULL)
    {
        return NULL;
    }
    
    /* allocating process */
    ksurface_proc_t *proc = malloc(sizeof(*proc));
    if(proc == NULL)
    {
        return NULL;
    }
    
    /* initilizing with mutual init */
    proc_create_mutual_init(proc);
    
    /* 1:1 rest copy */
    memcpy(&(proc->bsd), &(proc_copy->bsd), sizeof(kinfo_proc_t));
    memcpy(&(proc->nyx), &(proc_copy->nyx), sizeof(knyx_proc_t));
    
    return proc;
}

ksurface_proc_t *proc_create_from_proc(ksurface_proc_t *proc)
{
    /* null pointer check */
    if(proc == NULL)
    {
        return NULL;
    }
    
    /* creating a copy from the process passed */
    ksurface_proc_copy_t *proc_copy = proc_copy_for_proc(proc, kProcCopyOptionRetain);
    if(proc_copy == NULL)
    {
        return NULL;
    }
    
    /* creating process from copy of the original */
    ksurface_proc_t *nproc = proc_create_from_proc_copy(proc_copy);
    
    /* destroying copy that references the original process */
    proc_copy_destroy(proc_copy);
    
    return nproc;
}
