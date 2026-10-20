/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2025 - 2026 emexlab

 This file is part of Nyxian.

 Licensed under the emexLabs Public Source License, version 1.1
 (EPSL 1.1).

 Private use and modification are permitted under the license.
 Redistribution of source or binaries, modified or unmodified,
 requires prior written permission from emexLabs.

 External deployment is subject to the source-availability
 requirements and other conditions of the license.

 Provided "AS IS", without warranty, to the extent permitted by law.

 See LICENSE for the full license terms.
*/

#include <LindChain/ProcEnvironment/Utils/fd.h>
#include <LindChain/ProcEnvironment/Surface/libkern/bsd/proc_info.h>
#include <LindChain/Private/sys/guarded.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>

void get_all_fds(int *numFDs,
                 struct proc_fdinfo **fdinfo)
{
    pid_t pid = getpid();
    int bufferSize = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, NULL, 0);
    if(bufferSize <= 0)
    {
        return;
    }
    
    *fdinfo = malloc(bufferSize);
    if(!*fdinfo)
    {
        return;
    }
    
    /* getting process identifier information */
    int count = proc_pidinfo(pid, PROC_PIDLISTFDS, 0, *fdinfo, bufferSize);
    if(count <= 0)
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

    for(int i = 0; i < numFDs; i++)
    {
        if(i > 2 && !fd_is_guarded(fdinfo[i].proc_fd))
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
