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

#import <LindChain/ProcEnvironment/Surface/tty/attach.h>

/* typedef bool (*kvobject_event_handler_t)(kvobject_strong_t*,kvevent_type_t,uint8_t,void*); */
bool tty_proc_event_handler(kvobject_strong_t *kvo,
                            kvevent_type_t type,
                            uint8_t value,
                            void *pld)
{
    switch(type)
    {
        case kvObjEventDeinit:
        {
            ksurface_tty_t *tty = (ksurface_tty_t*)pld;
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
    ksurface_return_t ksr = kvo_event_register(proc, tty_proc_event_handler, NULL, tty);
    if(ksr != SURFACE_SUCCESS)
    {
        kvo_release(proc);
        return SURFACE_FAILED;
    }
    
    kvo_release(proc);
    return SURFACE_SUCCESS;
}
