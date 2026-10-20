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

#ifndef LIBKERN_OBJ_EVENT_H
#define LIBKERN_OBJ_EVENT_H

#import <LindChain/ProcEnvironment/Surface/libkern/obj/defs.h>
#include <mach/kern_return.h>

#define kvo_event_register(kvo, mask, handler, context, event) kvobject_event_register((kvobject_t*)kvo, (kvobject_event_type_t)mask, handler, context, event)
#define kvo_event_trigger(kvo, mask, value) kvobject_event_trigger((kvobject_t*)kvo, (kvobject_event_type_t)mask, value)

kern_return_t kvobject_event_register(kvobject_t *kvo, kvobject_event_type_t mask, kvobject_event_handler_t handler, void *context, kvobject_event_t **event);
void kvobject_event_trigger(kvobject_t *kvo, kvobject_event_type_t mask, uint64_t value);

#endif /* LIBKERN_OBJ_EVENT_H */
