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

#ifndef KVOBJECT_DEFS_H
#define KVOBJECT_DEFS_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdatomic.h>
#include <pthread.h>
#include <mach/mach.h>

#define KVEVENT_MAX 32

#define DEFINE_KVOBJECT_INIT_HANDLER(name) bool kvobject_handler_##name##_init(kvobject_t *kvo, kvobject_t *src)
#define DEFINE_KVOBJECT_DEINIT_HANDLER(name) void kvobject_handler_##name##_deinit(kvobject_t *kvo)

#define GET_KVOBJECT_INIT_HANDLER(name) kvobject_handler_##name##_init
#define GET_KVOBJECT_DEINIT_HANDLER(name) kvobject_handler_##name##_deinit

typedef struct kvobject kvobject_t;
typedef struct kvobject kvobject_strong_t;
typedef struct kvevent kvevent_t;

typedef bool (*kvobject_init_handler_t)(kvobject_t*,kvobject_t*);
typedef void (*kvobject_deinit_handler_t)(kvobject_t*);

typedef enum kvObjEvent {
    kvObjEventDeinit = 0,
    kvObjEventRetain,
    kvObjEventRelease,
    kvObjEventInvalidate,
    kvObjEventUnregister
} kvevent_type_t;

typedef void (*kvobject_event_handler_t)(kvobject_strong_t*,kvevent_type_t,uint8_t,void*);

struct kvevent {
    kvobject_event_handler_t handler;
    kvevent_type_t type;
    uint64_t event_token;
    void *pld;
};

struct kvobject {
    /*
     * reference count of an object if
     * it hits zero it will release
     * automatically.
     */
    _Atomic int refcount;
    
    /*
     * invalidation boolean value marks a
     * object as effectively useless, any new
     * retains will fail cuz it doesnt matter
     * anymore what a kernel operation might
     * wanna do with this object as its literally
     * marked as not useful anymore.
     */
    _Atomic bool invalid;
    
    /* state handlers for each object */
    kvobject_init_handler_t init;       /* can safely and shall be nulled if unused */
    kvobject_deinit_handler_t deinit;   /* can safely and shall be nulled if unused */
    
    /* events */
    pthread_rwlock_t event_rwlock;
    kvevent_t event[KVEVENT_MAX];
    uint8_t event_cnt;
    uint64_t event_token_counter;
    
    /*
     * main read-write lock of this structure,
     * mainly used when modifying kcproc.
     */
    pthread_rwlock_t rwlock;
    
    /* size for duplication */
    size_t size;
};

#endif /* KVOBJECT_DEFS_H */
