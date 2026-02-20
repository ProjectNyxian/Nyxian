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

#ifndef KVOBJECT_EVENT_H
#define KVOBJECT_EVENT_H

#import <LindChain/ProcEnvironment/Surface/obj/defs.h>
#import <LindChain/ProcEnvironment/Surface/obj/event.h>
#import <LindChain/ProcEnvironment/Surface/return.h>

ksurface_return_t kvobject_event_register(kvobject_strong_t *kvo, kvobject_event_handler_t handler, kvevent_type_t type, uint64_t *token, void *pld);
ksurface_return_t kvobject_event_unregister(kvobject_strong_t *kvo, uint64_t token);
void kvobject_event_trigger(kvobject_strong_t *kvo, kvevent_type_t type, uint8_t value);

#endif /* KVOBJECT_EVENT_H */
