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

#include <LindChain/ProcEnvironment/Utils/fd.h>
#import <LindChain/LiveContainer/Tweaks/libproc.h>
#include <stdlib.h>
#include <unistd.h>

void get_all_fds(int *numFDs,
                 struct proc_fdinfo **fdinfo)
{
    // Getting our own pid
    pid_t pid = getpid();
    int bufferSize = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, NULL, 0);
    if (bufferSize <= 0) return;
    
    // Allocating request buffer
    *fdinfo = malloc(bufferSize);
    if (!*fdinfo) return;
    
    // Getting process identifier information
    int count = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, *fdinfo, bufferSize);
    if (count <= 0)
    {
        free(*fdinfo);
        return;
    }
    
    *numFDs = count / sizeof(struct proc_fdinfo);
}

void close_all_fd(void)
{
    int numFDs = 0;
    struct proc_fdinfo *fdinfo = NULL;
    
    get_all_fds(&numFDs, &fdinfo);

    for (int i = 0; i < numFDs; i++)
    {
        close(fdinfo[i].proc_fd);
    }
}

int fdobject_assign(int fd,
                    fdobject_t *fdo)
{
    if(fdo == NULL)
    {
        return 1;
    }
    
    fdo->fdid = fd;
    if(fileport_makeport(fd, &(fdo->fp)) != 0)
    {
        return 2;
    }
    
    return 0;
}

fdobject_t *fdobject_alloc(int fd)
{
    fdobject_t *fdo = malloc(sizeof(fdobject_t));
    
    if(fdobject_assign(fd, fdo) != 0)
    {
        free(fdo);
        return NULL;
    }
    
    return fdo;
}

void fdobject_destroy(fdobject_t *fdo)
{
    if(fdo == NULL)
    {
        return;
    }
    
    mach_port_deallocate(mach_task_self(), fdo->fp);
}

void fdobject_apply(fdobject_t *fdo)
{
    if(fdo == NULL)
    {
        return;
    }
    
    fileport_dup2(fdo->fp, fdo->fdid);
}

void fdobject_free(fdobject_t *fdo)
{
    free(fdo);
}

fdmap_t *fdmap_current(void)
{
    fdmap_t *fm = malloc(sizeof(fdmap_t));
    
    if(fm == NULL)
    {
        return NULL;
    }
    
    int numfds = 0;
    struct proc_fdinfo *fdinfo;
    
    get_all_fds(&numfds, &fdinfo);
    
    fm->foarr = calloc(numfds, sizeof(fdobject_t));
    fm->foarr_cnt = numfds;
    
    if(fm->foarr == NULL)
    {
        free(fdinfo);
        free(fm);
        return NULL;
    }
    
    for(int i = 0; i < numfds; i++)
    {
        if(fdobject_assign(fdinfo[i].proc_fd, &(fm->foarr[i])) != 0)
        {
            for(; i > 0; i--)
            {
                fdobject_destroy(&(fm->foarr[i]));
            }
            free(fdinfo);
            free(fm->foarr);
            free(fm);
            return NULL;
        }
    }
    
    free(fdinfo);
    return fm;
}

void fdmap_apply(fdmap_t *fm)
{
    if(fm == NULL ||
       fm->foarr == NULL)
    {
        return;
    }
    
    for(int i = 0; i < fm->foarr_cnt; i++)
    {
        fdobject_apply(&(fm->foarr[i]));
    }
}
