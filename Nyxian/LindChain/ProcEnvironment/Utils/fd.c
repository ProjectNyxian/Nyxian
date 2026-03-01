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
