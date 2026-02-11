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
#import <LindChain/ProcEnvironment/Surface/proc/rw.h>
#import <LindChain/ProcEnvironment/Surface/proc/def.h>

DEFINE_KVOBJECT_INIT_HANDLER(proc)
{
    ksurface_proc_t *proc = (ksurface_proc_t*)kvo;
    
    /* nullify */
    memset(&(proc->kproc), 0, sizeof(ksurface_kproc_t));
    
    pthread_mutex_init(&(proc->kproc.children.mutex), NULL);
    gettimeofday(&proc->kproc.kcproc.bsd.kp_proc.p_un.__p_starttime, NULL);
}

DEFINE_KVOBJECT_DEINIT_HANDLER(proc)
{
    ksurface_proc_t *proc = (ksurface_proc_t*)kvo;
    
    pthread_mutex_destroy(&(proc->kproc.children.mutex));
}

static void proc_create_mutual_init(ksurface_proc_t *proc)
{
    /* marking process as referenced once */
    proc->header.refcount = 1;
    proc->header.invalid = false;
    
    /* initilizing rw lock and mutex */
    pthread_rwlock_init(&(proc->header.rwlock), NULL);
    pthread_mutex_init(&(proc->kproc.children.mutex), NULL);
    
    /* reseting the start time */
    gettimeofday(&proc->kproc.kcproc.bsd.kp_proc.p_un.__p_starttime, NULL);
}

ksurface_proc_t *proc_create(pid_t pid,
                             pid_t ppid,
                             const char *path)
{
    /* null pointer check */
    if(path == NULL)
    {
        return NULL;
    }
    
    /* allocating process */
    ksurface_proc_t *proc = (ksurface_proc_t*)kvobject_alloc(sizeof(ksurface_proc_t), GET_KVOBJECT_INIT_HANDLER(proc), GET_KVOBJECT_DEINIT_HANDLER(proc));
    
    /* null pointer check */
    if(proc == NULL)
    {
        return NULL;
    }
    
    /* setting bsd process information that are relevant currently */
    proc_setpid(proc, pid);
    proc_setppid(proc, ppid);
    proc_setentitlements(proc, 0);
    
    /* setting other bsd shit */
    proc->kproc.kcproc.bsd.kp_eproc.e_ucred.cr_groups[1] = 250;
    proc->kproc.kcproc.bsd.kp_eproc.e_ucred.cr_groups[2] = 286;
    proc->kproc.kcproc.bsd.kp_eproc.e_ucred.cr_groups[3] = 299;
    proc->kproc.kcproc.bsd.kp_eproc.e_ucred.cr_ngroups = 3;
    proc->kproc.kcproc.bsd.kp_proc.p_priority = PUSER;
    proc->kproc.kcproc.bsd.kp_proc.p_usrpri = PUSER;
    proc->kproc.kcproc.bsd.kp_eproc.e_tdev = -1;
    proc->kproc.kcproc.bsd.kp_eproc.e_flag = 2;
    proc->kproc.kcproc.bsd.kp_proc.p_stat = SRUN;
    proc->kproc.kcproc.bsd.kp_proc.p_flag = P_LP64 | P_EXEC;
    proc->kproc.kcproc.nyx.sid = 0;
    
    strlcpy(proc->kproc.kcproc.nyx.executable_path, path, PATH_MAX);
    const char *name = strrchr(path, '/');
    name = name ? name + 1 : path;
    strlcpy(proc->kproc.kcproc.bsd.kp_proc.p_comm, name, MAXCOMLEN);
    
    return proc;
}

ksurface_proc_t *proc_create_from_proc(ksurface_proc_t *proc)
{
    /* null pointer check */
    if(proc == NULL)
    {
        return NULL;
    }
    
    /* allocating process */
    ksurface_proc_t *nproc = calloc(1, sizeof(ksurface_proc_t));
    
    /* null pointer check*/
    if(nproc == NULL)
    {
        return NULL;
    }
    
    /* claiming read lock */
    KVOBJECT_RDLOCK(proc);
    
    /* 1:1 rest copy */
    memcpy(&(nproc->kproc.kcproc), &(proc->kproc.kcproc), sizeof(ksurface_kcproc_t));
    
    /* releasing it */
    KVOBJECT_UNLOCK(proc);
    
    /* initilizing with mutual init */
    proc_create_mutual_init(nproc);
    
    return nproc;
}
