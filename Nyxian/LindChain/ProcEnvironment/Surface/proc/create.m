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
#import <LindChain/ProcEnvironment/Surface/proc/def.h>

ksurface_proc_t *proc_create(pid_t pid,
                             pid_t ppid,
                             const char *path)
{
    /* allocating process */
    ksurface_proc_t *proc = calloc(1, sizeof(*proc));
    if(proc == NULL)
    {
        return NULL;
    }
    
    /* nullify process structure */
    memset(proc, 0, sizeof(*proc));
    
    /* marking process as referenced once */
    atomic_store(&proc->refcount, 1);
    atomic_store(&proc->dead, false);
    
    /* setting bsd process information that are relevant currently */
    proc_setpid(proc, pid);
    proc_setppid(proc, ppid);
    proc_setentitlements(proc, 0);
    
    if(path)
    {
        strncpy(proc->nyx.executable_path, path, PATH_MAX - 1);
        const char *name = strrchr(path, '/');
        name = name ? name + 1 : path;
        strncpy(proc->bsd.kp_proc.p_comm, name, MAXCOMLEN);
    }
    gettimeofday(&proc->bsd.kp_proc.p_un.__p_starttime, NULL);
    return proc;
}


