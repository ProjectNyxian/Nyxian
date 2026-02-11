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

#ifndef SURFACE_KVOBJECT_DEFS_H
#define SURFACE_KVOBJECT_DEFS_H

#include <stdint.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdatomic.h>
#include <pthread.h>

#define DEFINE_KVOBJECT_INIT_HANDLER(name) void kvobject_handler_##name##_init(kvobject_t *kvo)
#define DEFINE_KVOBJECT_DEINIT_HANDLER(name) void kvobject_handler_##name##_deinit(kvobject_t *kvo)
#define DEFINE_KVOBJECT_COPYIT_HANDLER(name) void kvobject_handler_##name##_copyit(kvobject_t *dst, kvobject_t *src)

#define GET_KVOBJECT_INIT_HANDLER(name) kvobject_handler_##name##_init
#define GET_KVOBJECT_DEINIT_HANDLER(name) kvobject_handler_##name##_deinit
#define GET_KVOBJECT_COPYIT_HANDLER(name) kvobject_handler_##name##_copyit

typedef enum kObjCopyOption {
    kObjCopyOptionRetainedCopy = 0,
    kObjCopyOptionConsumedReferenceCopy = 1,
    kObjCopyOptionStaticCopy = 2
} kvobj_copy_option_t;

typedef struct kvobject kvobject_t;
typedef void (*kvobject_handler_t)(kvobject_t*);
typedef void (*kvobject_duo_handler_t)(kvobject_t*,kvobject_t*);

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
    kvobject_handler_t init;        /* can safely and shall be nulled if unused */
    kvobject_handler_t deinit;      /* can safely and shall be nulled if unused */
    kvobject_duo_handler_t copyit;  /* can safely and shall be nulled if unused */
    
    /*
     * main read-write lock of this structure,
     * mainly used when modifying kcproc.
     */
    pthread_rwlock_t rwlock;
    
    /* size for duplication */
    size_t size;
};

#endif /* SURFACE_KVOBJECT_DEFS_H */
