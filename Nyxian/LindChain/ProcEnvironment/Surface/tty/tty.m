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
#import <sys/poll.h>
#include <stdio.h>

static int pump_master_to_slave(ksurface_tty_t *tty,
                                int m,
                                int s)
{
    ssize_t n = read(m, tty->buf, sizeof(tty->buf));
    if(n <= 0)
    {
        return -1;
    }
    
    ssize_t new_n = 0;
    for(ssize_t i = 0; i < n; i++)
    {
        /* removing high bit on ISTRIP */
        if(tty->t.c_iflag & ISTRIP)
        {
            tty->buf[i] = tty->buf[i] & 0b01111111;
        }
        
        /* if ignore then dont do anything */
        if((tty->t.c_iflag & IGNCR) &&
           tty->buf[i] == '\r')
        {
            continue;
        }
        
        /* handling return to newline translation */
        if(tty->t.c_iflag & ICRNL &&
           tty->buf[i] == '\r')
        {
            tty->buf[i] = '\n';
        }
        
        /* the inverse of the previous translation */
        else if(tty->t.c_iflag & INLCR &&
                tty->buf[i] == '\n')
        {
            tty->buf[i] = '\r';
        }
        
        tty->buf[new_n++] = tty->buf[i];
    }
    
    ssize_t off = 0;
    while(off < n)
    {
        ssize_t w = write(s, tty->buf + off, n - off);
        if(w <= 0)
        {
            return -1;
        }
        off += w;
    }
    
    
    return 0;
}

static int pump_slave_to_master(ksurface_tty_t *tty,
                                int m,
                                int s)
{
    ssize_t n = read(s, tty->buf, sizeof(tty->buf));
    ssize_t new_n = 0;
    if(n <= 0)
    {
        return -1;
    }
    
    if(!(tty->t.c_oflag & OPOST))
    {
        goto write_out;
    }
    
    for(ssize_t i = 0; i < n; i++)
    {
        uint8_t c = tty->buf[i];
        
        if(c == '\n')
        {
            /* very common flag that will fix the terminal inbuilt post process lol */
            if(tty->t.c_oflag & ONLCR)
            {
                tty->obuf[new_n++] = '\r';
                tty->obuf[new_n++] = '\n';
                continue;
            }
        }
        else if(c == '\r')
        {
            /* translate return to newline */
            if(tty->t.c_oflag & OCRNL)
            {
                tty->obuf[new_n++] = '\n';
                continue;
            }
            
            
            if((tty->t.c_oflag & ONOCR) && tty->ws.ws_col == 0)
            {
                continue;
            }
        }
        
        tty->obuf[new_n++] = c;
    }
    
write_out:
    {
        const uint8_t *out = (uint8_t*)((tty->t.c_oflag & OPOST) ? tty->obuf : tty->buf);
        ssize_t out_n = (tty->t.c_oflag & OPOST) ? new_n : n;
        
        ssize_t off = 0;
        while(off < out_n)
        {
            ssize_t w = write(m, out + off, out_n - off);
            if(w <= 0) return -1;
            off += w;
        }
    }
    
    return 0;
}

static void *tty_pump_thread(void *arg)
{
    ksurface_tty_t *tty = arg;

    int m = tty->core_masterfd;
    int s = tty->core_slavefd;

    struct pollfd fds[2] = {
        { .fd = m, .events = POLLIN },
        { .fd = s, .events = POLLIN },
    };

    while(tty->alive)
    {
        int r = poll(fds, 2, -1);
        if(r <= 0)
        {
            continue;
        }

        if(fds[0].revents & POLLIN)
        {
            if(pump_master_to_slave(tty, m, s) < 0)
            {
                break;
            }
        }

        if(fds[1].revents & POLLIN)
        {
            if(pump_slave_to_master(tty, m, s) < 0)
            {
                break;
            }
        }
    }

    return NULL;
}

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
        case kvObjEventSnapshot:
        case kvObjEventCopy:
            /* copy not supported */
            return -1;
        case kvObjEventInit:
        {
            /* zero object out! */
            kv_content_zero(tty);
            
            /* creating pipe */
            if(socketpair(AF_UNIX, SOCK_STREAM, 0, tty->masterfds) != 0)
            {
                return -1;
            }
            
            /* creating pipe */
            if(socketpair(AF_UNIX, SOCK_STREAM, 0, tty->slavefds) != 0)
            {
                return -1;
            }
            
            /* getting unique object pointer */
            struct socket_fdinfo si;
            
            if(proc_pidfdinfo(getpid(), tty->slavefds[0], PROC_PIDFDSOCKETINFO, &si, sizeof(si)) <= 0)
            {
                /* notify me, if this happens, apple again had to change something */
                goto out_fail;
            }
            
            /* the 2nd fd is always the fd the tty object manages */
            tty->kslavecid = si.psi.soi_proto.pri_kern_ctl.kcsi_id;
            tty->masterfd = tty->masterfds[0];
            tty->core_masterfd = tty->masterfds[1];
            tty->slavefd = tty->slavefds[0];
            tty->core_slavefd = tty->slavefds[1];
            
            /* inserting own tty object */
            tty_table_wrlock();
            if(radix_insert(&(ksurface->tty_info.tty), tty->kslavecid, tty) != 0)
            {
                tty_table_unlock();
                goto out_fail;
            }
            tty_table_unlock();
            
            /* lets start da factory */
            tty->alive = 1;
            
            if(pthread_create(&tty->pump_thread, NULL, tty_pump_thread, tty) != 0)
            {
                goto out_fail;
            }
            
            return 0;
        
        out_fail:
            close(tty->slavefds[0]);
            close(tty->slavefds[1]);
            close(tty->masterfds[0]);
            close(tty->masterfds[1]);
            return -1;
        }
        case kvObjEventDeinit:
            klog_log(@"tty:deinit", @"deinitilizing tty @ %p", tty);
            
            /* making sure deinit happens, with the threads consent */
            tty->alive = 0;
            
            shutdown(tty->core_masterfd, SHUT_RDWR);
            shutdown(tty->core_slavefd, SHUT_RDWR);

            pthread_join(tty->pump_thread, NULL);
            
            close(tty->slavefds[0]);
            close(tty->slavefds[1]);
            close(tty->masterfds[0]);
            close(tty->masterfds[1]);
            
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
