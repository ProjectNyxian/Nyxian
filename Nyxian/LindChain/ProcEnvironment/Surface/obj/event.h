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

#ifndef KVOBJECT_EVENT_H
#define KVOBJECT_EVENT_H

#import <LindChain/ProcEnvironment/Surface/obj/defs.h>
#import <LindChain/ProcEnvironment/Surface/obj/event.h>
#import <LindChain/ProcEnvironment/Surface/return.h>

#define kvo_event_register(kvo, handler, context, event) kvobject_event_register((kvobject_t*)kvo, handler, context, event)
#define kvo_event_unregister(kvo, token) kvobject_event_unregister((kvobject_t*)kvo, token)
#define kvo_event_trigger(kvo, type, value) kvobject_event_trigger((kvobject_t*)kvo, type, value)

ksurface_return_t kvobject_event_register(kvobject_strong_t *kvo, kvobject_event_handler_t handler, void *context, kvobject_event_t **event);
ksurface_return_t kvobject_event_unregister(kvobject_event_t *event);
void kvobject_event_trigger(kvobject_strong_t *kvo, kvobject_event_type_t type, uint8_t value);

#endif /* KVOBJECT_EVENT_H */
