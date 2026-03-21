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

#import <LindChain/ProcEnvironment/Surface/tty/attach.h>

bool tty_proc_event_handler(kvobject_event_type_t type,
                            uint8_t value,
                            kvobject_event_t *event)
{
    switch(type)
    {
        case kvObjEventDeinit:
        {
            return true;
        }
        case kvObjEventUnregister:
        {
            ksurface_tty_t *tty = (ksurface_tty_t*)(event->ctx);
            kvo_release(tty);
            return true;
        }
        default:
            return false;
    }
}

ksurface_return_t tty_attach_proc(ksurface_proc_t *proc,
                                  ksurface_tty_t *tty)
{
    /* retain process */
    if(!kvo_retain(proc))
    {
        return SURFACE_RETAIN_FAILED;
    }
    
    /*
     * attach to process lifecycle
     * and consume callers reference.
     */
    ksurface_return_t ksr = kvo_event_register(proc, 0, tty_proc_event_handler, tty, NULL);
    if(ksr != SURFACE_SUCCESS)
    {
        kvo_release(proc);
        return SURFACE_FAILED;
    }
    
    kvo_wrlock(proc);
    proc->bsd.kp_proc.p_flag |= P_CONTROLT;
    
    /* TODO: implement pgrp support */
    tty->pgrp = proc_getsid(proc);
    kvo_unlock(proc);
    
    kvo_release(proc);
    return SURFACE_SUCCESS;
}
