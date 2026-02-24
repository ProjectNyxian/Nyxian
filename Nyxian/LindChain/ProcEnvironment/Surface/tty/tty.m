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

DEFINE_KVOBJECT_MAIN_EVENT_HANDLER(tty)
{
    ksurface_tty_t *tty = (ksurface_tty_t*)kvarr[0];
    
    switch(type)
    {
        case kvObjEventInit:
        {
            /* creating pipe */
            int fds[2] = {};
            if(pipe(fds) != 0)
            {
                return -1;
            }
            
            /* getting unique handler */
            struct pipe_fdinfo pi;
            if(proc_pidinfo(getpid(), fds[0], PROC_PIDFDPIPEINFO, &pi, sizeof(pi)) != 0)
            {
                close(fds[0]);
                close(fds[1]);
                return -1;
            }
            
            tty->slavehandle = pi.pipeinfo.pipe_handle;
            
            /* inserting own tty object */
            tty_table_wrlock();
            if(radix_insert(&(ksurface->tty_info.tty), tty->slavehandle, tty) != 0)
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
            
            /* removing own tty object */
            tty_table_wrlock();
            radix_remove(&(ksurface->tty_info.tty), tty->slavehandle);
            tty_table_unlock();
            
            /* fallthrough */
        default:
            return 0;
    }
    
    return 0;
}

