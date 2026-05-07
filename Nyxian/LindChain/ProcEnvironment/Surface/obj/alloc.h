/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 mach-port-t

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

#ifndef KVOBJECT_ALLOC_H
#define KVOBJECT_ALLOC_H

#import <LindChain/ProcEnvironment/Surface/obj/defs.h>

#define kvo_alloc(main) (void*)kvobject_alloc(main)
#define kvo_alloc_fastpath(name) (void*)kvobject_alloc(GET_KVOBJECT_MAIN_EVENT_HANDLER(name))
#define kvo_copy(kvo) (void*)kvobject_copy((kvobject_t*)kvo)
#define kvo_snapshot(kvo, option) (void*)kvobject_snapshot((kvobject_t*)kvo, option)

kvobject_strong_t *kvobject_alloc(kvobject_main_event_handler_t handler);
kvobject_strong_t *kvobject_copy(kvobject_t *kvo);
kvobject_snapshot_t *kvobject_snapshot(kvobject_t *kvo, kvobject_snapshot_options_t option);

#endif /* KVOBJECT_ALLOC_H */
