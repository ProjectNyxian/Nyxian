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

#define DEFINE_KVOBJECT_MAIN_EVENT_HANDLER(name) int64_t kvobject_event_handler_##name##_main(kvobject_t **kvarr, kvobject_event_type_t type)
#define GET_KVOBJECT_MAIN_EVENT_HANDLER(name) kvobject_event_handler_##name##_main

/* enumeration of kernel virt object base types */
enum kvObjBaseType {
    kvObjBaseTypeObject = 0,                        /* normal allocated object with referencing */
    kvObjBaseTypeObjectSnapshot = 1,                /* snapshot of object also with referencing, but with seperate memory */
};

/* enumeration of kernel virt object events */
enum kvObjEvent {
    kvObjEventInit = 0,                             /* object initilizes                            MARK: important for main event handler */
    kvObjEventDeinit,                               /* object deinitilizes                          MARK: important for main event handler */
    kvObjEventCopy,                                 /* object copies into new object                MARK: important for main event handler */
    kvObjEventSnapshot,                             /* object snapshots into snapshotted object     MARK: important for main event handler */
    kvObjEventInvalidate,                           /* object becomes invalidated */
    kvObjEventUnregister,                           /* object event handler gets unregistered, only called on the affected handler */
    kvObjEventCustom0,                              /* custom object events */
    kvObjEventCustom1,
    kvObjEventCustom2,
    kvObjEventCustom3,
    kvObjEventCustom4,
    kvObjEventCustom5,
    kvObjEventCustom6,
    kvObjEventCustom7,
    kvObjEventCustom8,
    kvObjEventCustom9,
    kvObjEventCustom10
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

/* kernel virt object event type */
typedef struct kvevent      kvobject_event_t;

/* kernel virt object enumeration types */
typedef enum kvObjBaseType  kvobject_base_type_t;
typedef enum kvObjEvent     kvobject_event_type_t;
typedef enum kvObjState     kvobject_state_t;
typedef enum kvObjSnap      kvobject_snapshot_options_t;

typedef int64_t (*kvobject_main_event_handler_t)(kvobject_t**, kvobject_event_type_t);
typedef bool (*kvobject_event_handler_t)(kvobject_event_type_t, uint8_t, kvobject_event_t*);

struct kvevent {
    kvobject_event_t *previous;                     /* pointer to previous event */
    kvobject_event_t *next;                         /* pointer to next event */
    kvobject_t *owner;                              /* pointer of who owns the event */
    kvobject_event_handler_t handler;               /* pointer to handler */
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
    
    /* state handlers for each object */
    kvobject_main_event_handler_t main_handler;
    
    /* events */
    pthread_rwlock_t event_rwlock;
    kvobject_event_t *event;
    
    /*
     * main read-write lock of this structure,
     * mainly used when modifying kcproc.
     */
    pthread_rwlock_t rwlock;
    
    /* size for duplication */
    size_t size;
    
    /* reference back to original (for snapshot) */
    kvobject_strong_t *orig;
};

#endif /* KVOBJECT_DEFS_H */
