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

#ifndef KVOBJECT_DEFS_H
#define KVOBJECT_DEFS_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdatomic.h>
#include <pthread.h>
#include <mach/mach.h>
#include <os/lock.h>

#define DEFINE_KVOBJECT_MAIN_EVENT_HANDLER(name) int64_t kvobject_event_handler_##name##_main(kvobject_t **kvarr, kvobject_event_type_t type)
#define GET_KVOBJECT_MAIN_EVENT_HANDLER(name) kvobject_event_handler_##name##_main

#define kv_content_zero(kvo) bzero(((char*)kvo) + sizeof(kvobject_t), sizeof(*kvo) - sizeof(kvobject_t))

#define KVOBJECT_EVENT_MAX 128

/* enumeration of kernel virt object base types */
enum kvObjBaseType {
    kvObjBaseTypeObject = 0,                        /* normal allocated object with referencing */
    kvObjBaseTypeObjectSnapshot = 1,                /* snapshot of object also with referencing, but with seperate memory */
    kvObjBaseTypeObjectRCU = 2,                     /* rcu allocated object with referencing  */
};

/* enumeration of kernel virt object events */
enum kvObjEvent {
    kvObjEventNone = 0,                             /* nothing, but for event registration relevant, they cannot escape getting deinit or unregistration notif */
    kvObjEventInit = 1ull << 0,                     /* object initilizes                            MARK: important for main event handler */
    kvObjEventDeinit = 1ull << 1,                   /* object deinitilizes                          MARK: important for main event handler */
    kvObjEventCopy = 1ull << 2,                     /* object copies into new object                MARK: important for main event handler */
    kvObjEventSnapshot = 1ull << 3,                 /* object snapshots into snapshotted object     MARK: important for main event handler */
    kvObjEventInvalidate = 1ull << 4,               /* object becomes invalidated */
    kvObjEventUnregister = 1ull << 5,               /* object event handler gets unregistered, only called on the affected handler */
    kvObjEventCustom0 = 1ull << 6,                  /* custom object events */
    kvObjEventCustom1 = 1ull << 7,
    kvObjEventCustom2 = 1ull << 8,
    kvObjEventCustom3 = 1ull << 9,
    kvObjEventCustom4 = 1ull << 10,
    kvObjEventCustom5 = 1ull << 11,
    kvObjEventCustom6 = 1ull << 12,
    kvObjEventCustom7 = 1ull << 13,
    kvObjEventCustom8 = 1ull << 14,
    kvObjEventCustom9 = 1ull << 15,
    kvObjEventCustom10 = 1ull << 16
};

/* enumeration of kernel virt object states */
enum kvObjState {
    kvObjStateNormal = 0,                           /* object is in normal state */
    kvObjStateInvalid                               /* object is invalidated and cannot be retained, only released, its used to mark a object as meaningless */
};

/* enumeration for type of snapshotting */
enum kvObjSnap {
    kvObjSnapStatic = 0,                            /* dont create reference back nor set orig pointer */
    kvObjSnapReferenced,                            /* creates new reference and sets orig pointer */
    kvObjSnapConsumeReference                       /* consumes callers reference and sets orig pointer */
};

/* kernel virt object types */
typedef struct kvobject     kvobject_t;             /* weak object type (needs retain on use) */
typedef struct kvobject     kvobject_strong_t;      /* strong object (referenced for calle) */
typedef struct kvobject     kvobject_snapshot_t;    /* snapshot of object (references object usually) */
typedef struct rcu_kvobject rcu_kvobject_t;         /* weak rcu object */
typedef struct rcu_kvobject rcu_kvobject_strong_t;  /* strong rcu object */

/* kernel virt object event type */
typedef struct kvevent      kvobject_event_t;

/* kernel virt object enumeration types */
typedef enum kvObjBaseType  kvobject_base_type_t;
typedef enum kvObjEvent     kvobject_event_type_t;
typedef enum kvObjState     kvobject_state_t;
typedef enum kvObjSnap      kvobject_snapshot_options_t;

typedef int64_t (*kvobject_main_event_handler_t)(kvobject_t**, kvobject_event_type_t);
typedef bool (*kvobject_event_handler_t)(kvobject_event_type_t, uint64_t, kvobject_event_t*);

struct kvevent {
    kvobject_event_t *previous;                     /* pointer to previous event */
    kvobject_event_t *next;                         /* pointer to next event */
    kvobject_t *owner;                              /* pointer of who owns the event */
    kvobject_event_handler_t handler;               /* pointer to handler */
    kvobject_event_type_t mask;                     /* event mask decides for what the handler does things */
    pthread_mutex_t in_use;                         /* usage marker (can cause freeze if no reference to the object exists anymore) */
    void *ctx;                                      /* pointer to payload MARK: if heap allocated, deallocate it on unregistration */
};

struct kvobject {
    /* type of object */
    kvobject_base_type_t base_type;
    
    /*
     * reference count of an object if
     * it hits zero it will release
     * automatically.
     */
    _Atomic int refcount;
    
    /*
     * the object state value marks a
     * object as effectively useless if its state
     * is invalid, any new retains will fail cuz it
     * doesnt matter anymore what a kernel operation
     * might wanna do with this object as its literally
     * marked as not useful anymore.
     */
    _Atomic kvobject_state_t state;
    
    /* state handler for each object */
    kvobject_main_event_handler_t main_handler;
    
    /* events */
    pthread_rwlock_t event_rwlock;
    uint64_t event_count;
    kvobject_event_t *event;
    
    /*
     * main read-write lock of this structure,
     * mainly used when modifying kcproc.
     */
    pthread_rwlock_t rwlock;
    
    /* reference back to original (for snapshot) */
    kvobject_strong_t *orig;
};

struct rcu_kvobject {
    /* object header (yes rcu objects them selves will be objects) */
    kvobject_t header;
    
    /* current kvobject */
    kvobject_strong_t * current;
    
    /* locks for concurrence safety */
    os_unfair_lock cur_lock;
    os_unfair_lock wrt_lock;
};

#endif /* KVOBJECT_DEFS_H */
