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

#ifndef LIBKERN_OBJ_ALLOC_H
#define LIBKERN_OBJ_ALLOC_H

#import <LindChain/ProcEnvironment/Surface/libkern/obj/defs.h>

#define kvo_alloc(main) (void*)kvobject_alloc(main)
#define kvo_alloc_fastpath(name) (void*)kvobject_alloc(GET_KVOBJECT_MAIN_EVENT_HANDLER(name))
#define kvo_copy(kvo) (void*)kvobject_copy((kvobject_t*)kvo)
#define kvo_snapshot(kvo, option) (void*)kvobject_snapshot((kvobject_t*)kvo, option)
#define kvo_size(handler) kvobject_size(handler)
#define kvo_snapshot_into_mem(mem, kvo, option) (void*)kvobject_snapshot_into_mem(mem, (kvobject_t*)kvo, option)

kvobject_t *kvobject_alloc(kvobject_main_event_handler_t handler);
kvobject_t *kvobject_copy(kvobject_t *kvo);
kvobject_snapshot_t *kvobject_snapshot(kvobject_t *kvo, kvobject_snapshot_options_t option);
size_t kvobject_size(kvobject_main_event_handler_t handler);
bool kvobject_snapshot_into_mem(void *mem, kvobject_t *kvo, kvobject_snapshot_options_t option);

#endif /* LIBKERN_OBJ_ALLOC_H */
