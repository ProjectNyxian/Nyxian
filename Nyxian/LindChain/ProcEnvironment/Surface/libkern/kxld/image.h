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

#ifndef LIBKERN_KXLD_IMAGE_H
#define LIBKERN_KXLD_IMAGE_H

#include <LindChain/ProcEnvironment/Surface/libkern/obj/kvobject.h>
#include <LindChain/ProcEnvironment/LiveContainer/LCMachOUtils.h>
#include <LindChain/ProcEnvironment/Surface/trust/signing.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/param.h>
#include <mach-o/loader.h>
#include <mach-o/ldsyms.h>

/*
 * this is not a toy API once a malicious kext is
 * loaded there is unfourtunetly nothing I can do
 * to safe your data stored in Nyxian, use this
 * API at your own risk. May the gods of kernel
 * engineering be with you my friend.
 */
#define KSURFACE_KMOD_MAGIC 0x4B4D4F44
#define KSURFACE_KMOD_ABI_VERSION 1
#define KMOD_MAX_NAME 64
#define KMOD_MAX_DEPENDENCIES 32

#define KMOD_VERSION(major, minor, patch) \
    (((uint32_t)(major) & 0xFF) << 16) | \
    (((uint32_t)(minor) & 0xFF) << 8)  | \
     ((uint32_t)(patch) & 0xFF)

#define KMOD_VERSION_MAJOR(v) ((v >> 16) & 0xFF)
#define KMOD_VERSION_MINOR(v) ((v >> 8) & 0xFF)
#define KMOD_VERSION_PATCH(v) (v & 0xFF)

#define KMOD_VERSION_EQ(v, major, minor, patch) ((uint32_t)(v) == KMOD_VERSION((major), (minor), (patch)))
#define KMOD_VERSION_NE(v, major, minor, patch) ((uint32_t)(v) != KMOD_VERSION((major), (minor), (patch)))
#define KMOD_VERSION_LT(v, major, minor, patch) ((uint32_t)(v) < KMOD_VERSION((major), (minor), (patch)))
#define KMOD_VERSION_LE(v, major, minor, patch) ((uint32_t)(v) <= KMOD_VERSION((major), (minor), (patch)))
#define KMOD_VERSION_GT(v, major, minor, patch) ((uint32_t)(v) > KMOD_VERSION((major), (minor), (patch)))
#define KMOD_VERSION_GE(v, major, minor, patch) ((uint32_t)(v) >= KMOD_VERSION((major), (minor), (patch)))

#define KMOD_VERSION_AT_LEAST(v, major, minor, patch) KMOD_VERSION_GE((v), (major), (minor), (patch))
#define KMOD_VERSION_AT_MOST(v, major, minor, patch) KMOD_VERSION_LE((v), (major), (minor), (patch))

#define KMOD_VERSION_IN_RANGE(v, \
                              min_major, min_minor, min_patch, \
                              max_major, max_minor, max_patch) \
    (KMOD_VERSION_GE((v), (min_major), (min_minor), (min_patch)) && \
     KMOD_VERSION_LE((v), (max_major), (max_minor), (max_patch)))


#define KMOD_ABI_VERSION_SUPPORTED(abi) ((uint32_t)(abi) == KSURFACE_KMOD_ABI_VERSION)

#define EXPORT_KSURFACE_MODULE(...) \
    __attribute__((used, section("__DATA,__ksurfacemod"))) \
    const kinfo_mod_t ksurface_kext_info = __VA_ARGS__;

typedef enum {
    KMOD_FLAG_NONE              = 0,        /* sentinel */
    KMOD_FLAG_PERSISTENT        = (1 << 0), /* cannot be unloaded */
    KMOD_FLAG_BACKGROUND_ONLY   = (1 << 1), /* requires it's own thread MARK: unsupported currently */
    KMOD_FLAG_OVERRIDE_CORE     = (1 << 2), /* can override ksurface symbols for other kexts */
    KMOD_FLAG_ALLOW_UNRESOLVED  = (1 << 3), /* allows unresolved symbols, useful for kexts who have broader compatibility guards that are aware of APIs not existing in certain versions of their dependencies and choose other code paths in that case.*/
} kmod_flags_t;

typedef struct {
    char identifier[KMOD_MAX_NAME];
    uint32_t min_version;
    uint32_t max_version;
} kmod_dependency_t;

typedef struct kinfo_mod {
    /* identity */
    uint32_t magic;
    uint32_t abi_version;
    const char identifier[KMOD_MAX_NAME];
    uint32_t version;
    uint64_t flags;
    uint32_t dependency_count;
    
    /* handlers */
    kern_return_t (*init)(void);    /* runs synchronious with the other loads, so don't waste resources, except you specify KMOD_FLAG_BACKGROUND_ONLY */
    kern_return_t (*deinit)(void);  /* runs synchronious with the other loads, so don't waste resources, except you specify KMOD_FLAG_BACKGROUND_ONLY */
    kern_return_t (*start)(void);   /* always runs on background thread */
    kern_return_t (*stop)(void);
    
    /* dependencies */
    kmod_dependency_t dependencies[];
} kinfo_mod_t;

typedef struct {
    kvobject_t kvo_header;
    
    char path[MAXPATHLEN];
    intptr_t slide;
    off_t sliceOffset;
    void *base;
    uint64_t len;
    struct mach_header_64 *header;
    kinfo_mod_t *mod;
    
    bool isInitialized;
    bool isStarted;
    bool safeToUnmap;
    bool dependenciesResolved;
} kxld_image_info_t;

DEFINE_KVOBJECT_MAIN_EVENT_HANDLER(kxld_image);

#endif /* LIBKERN_KXLD_IMAGE_H */
