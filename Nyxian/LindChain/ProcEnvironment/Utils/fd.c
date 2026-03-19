/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 cr4zyengineer

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#include <LindChain/ProcEnvironment/Utils/fd.h>
#include <LindChain/LiveContainer/Tweaks/libproc.h>
#include <LindChain/Private/sys/guarded.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>

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
        if(!fd_is_guarded(fdinfo[i].proc_fd))
        {
            close(fdinfo[i].proc_fd);
        }
    }
}

bool fd_is_guarded(int fd)
{
    guardid_t unknownguard = 0;
    change_fdguard_np(fd, &unknownguard, GUARD_CLOSE, &unknownguard, GUARD_CLOSE, NULL);
    return (errno == EPERM);
}
