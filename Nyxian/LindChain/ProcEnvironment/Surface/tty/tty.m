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

#import <LindChain/ProcEnvironment/Surface/tty/tty.h>
#import <LindChain/LiveContainer/Tweaks/libproc.h>
#import <LindChain/ProcEnvironment/Utils/klog.h>
#import <LindChain/ProcEnvironment/Surface/surface.h>
#import <sys/socket.h>

DEFINE_KVOBJECT_MAIN_EVENT_HANDLER(tty)
{
    /* handle size request */
    if(kvarr == NULL)
    {
        return (int64_t)sizeof(ksurface_tty_t);
    }
    
    ksurface_tty_t *tty = (ksurface_tty_t*)kvarr[0];
    
    switch(type)
    {
        case kvObjEventCopy:
            /* copy not supported */
            return -1;
        case kvObjEventInit:
        {
            /* creating pipe */
            int fds[2] = {};
            if(socketpair(AF_UNIX, SOCK_STREAM, 0, fds) != 0)
            {
                return -1;
            }
            
            /* getting unique object pointer */
            struct socket_fdinfo si;
            
            if(proc_pidfdinfo(getpid(), fds[1], PROC_PIDFDSOCKETINFO, &si, sizeof(si)) <= 0)
            {
                /* notify me, if this happens, apple again had to change something */
                close(fds[0]);
                close(fds[1]);
                return -1;
            }
            
            tty->kslavecid = si.psi.soi_proto.pri_kern_ctl.kcsi_id;
            tty->masterfd = fds[0];
            tty->slavefd = fds[1];
            
            /* inserting own tty object */
            tty_table_wrlock();
            if(radix_insert(&(ksurface->tty_info.tty), tty->kslavecid, tty) != 0)
            {
                close(fds[0]);
                close(fds[1]);
                return -1;
                tty_table_unlock();
            }
            tty_table_unlock();
            
            return 0;
        }
        case kvObjEventDeinit:
            klog_log(@"tty:deinit", @"deinitilizing tty @ %p", tty);
            
            close(tty->masterfd);
            close(tty->slavefd);
            
            /* removing own tty object */
            tty_table_wrlock();
            radix_remove(&(ksurface->tty_info.tty), tty->kslavecid);
            tty_table_unlock();
            
            /* fallthrough */
        default:
            return 0;
    }
    
    return 0;
}
