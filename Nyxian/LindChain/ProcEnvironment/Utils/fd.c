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

int fd_queue_create(int *q)
{
    if(socketpair(AF_UNIX, SOCK_STREAM, 0, q) == -1)
    {
        return -1;
    }
    return 0;
}

int fd_queue_append_fp(int inq,
                       fileport_t fp,
                       int mfd)
{
    int fd = fileport_makefd(fp);
    
    if(fd < 0)
    {
        return -1;
    }
    
    return fd_queue_append_fd(inq, fd, mfd);
}

int fd_queue_append_fd(int inq,
                       int fd,
                       int mfd)
{
    struct msghdr msg = {0};
    
    struct {
        int meta;
    } data;
    
    data.meta = mfd;
    
    struct iovec io = {
        .iov_base = &data,
        .iov_len = sizeof(data)
    };
    
    msg.msg_iov = &io;
    msg.msg_iovlen = 1;
    
    char cmsgbuf[CMSG_SPACE(sizeof(int))];
    memset(cmsgbuf, 0, sizeof(cmsgbuf));
    
    msg.msg_control = cmsgbuf;
    msg.msg_controllen = sizeof(cmsgbuf);
    
    struct cmsghdr *cmsg = CMSG_FIRSTHDR(&msg);
    cmsg->cmsg_level = SOL_SOCKET;
    cmsg->cmsg_type = SCM_RIGHTS;
    cmsg->cmsg_len = CMSG_LEN(sizeof(int));
    
    *((int *) CMSG_DATA(cmsg)) = fd;
    
    msg.msg_controllen = cmsg->cmsg_len;
    
    if(sendmsg(inq, &msg, 0) < 0)
    {
        return -1;
    }
    
    return 0;
}

int fd_queue_apply(int outq)
{
    struct msghdr msg = {0};

    struct {
        int meta;
    } data;
    
    struct iovec io = {
        .iov_base = &data,
        .iov_len = sizeof(data)
    };
    
    msg.msg_iov = &io;
    msg.msg_iovlen = 1;
    
    char cmsgbuf[CMSG_SPACE(sizeof(int))];
    msg.msg_control = cmsgbuf;
    msg.msg_controllen = sizeof(cmsgbuf);
    
    while(true)
    {
        if(recvmsg(outq, &msg, 0) < 0)
        {
            break;
        }
        
        int mfd = data.meta;
        int rfd = -1;
        
        struct cmsghdr *cmsg = CMSG_FIRSTHDR(&msg);
        if(cmsg &&
           cmsg->cmsg_level == SOL_SOCKET &&
           cmsg->cmsg_type == SCM_RIGHTS)
        {
            rfd = *((int *) CMSG_DATA(cmsg));
        }
        
        if(rfd < 0)
        {
            break;
        }
        
        if(rfd != mfd)
        {
            dup2(rfd, mfd);
            close(rfd);
        }
    }
    
    return 0;
}
