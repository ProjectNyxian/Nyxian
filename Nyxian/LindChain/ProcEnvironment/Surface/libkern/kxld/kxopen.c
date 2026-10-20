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

#include <LindChain/ProcEnvironment/Surface/libkern/patch.h>
#include <LindChain/ProcEnvironment/Surface/libkern/klog.h>
#include <LindChain/ProcEnvironment/Surface/libkern/kpanic.h>
#include <LindChain/ProcEnvironment/Surface/libkern/kxld/kxopen.h>
#include <LindChain/ProcEnvironment/Surface/libkern/kxld/validation.h>
#include <LindChain/ProcEnvironment/Surface/libkern/kxld/mapper.h>
#include <LindChain/ProcEnvironment/Surface/libkern/kxld/fixup.h>
#include <LindChain/ProcEnvironment/Surface/libkern/kxld/reseal.h>
#include <LindChain/ProcEnvironment/Surface/libkern/kxld/image.h>
#include <LindChain/ProcEnvironment/Surface/libkern/kxld/kmod.h>
#include <LindChain/ProcEnvironment/Surface/libkern/kxld/export.h>
#include <LindChain/ProcEnvironment/Surface/libkern/kxld/init.h>
#include <LindChain/ProcEnvironment/Surface/libkern/kxld/objc.h>
#include <LindChain/ProcEnvironment/Surface/libkern/kxld/resolve.h>
#include <LindChain/ProcEnvironment/Surface/trust/signing.h>
#include <LindChain/ProcEnvironment/LiveContainer/LCMachOUtils.h>
#include <ksurface_config.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <fcntl.h>
#include <sys/mman.h>
#include <sys/param.h>
#include <mach-o/loader.h>
#include <mach-o/ldsyms.h>
#include <os/lock.h>
#include <pthread.h>

static bool g_kxld_sealed = false;
static os_unfair_lock g_kxld_lock = OS_UNFAIR_LOCK_INIT;

LIBKERN_DEFINE_PATCHABLE(void *, ksurface_kext_thread, (void *ii))
{
    /* invoking kextension start */
    kxld_image_info_t *image_info = (kxld_image_info_t*)ii;
    klog_log("kextloader:thread", "spinning up kext '%s'", image_info->mod->identifier);
    image_info->mod->start();
    image_info->isStarted = false;  /* because it stopped */
    if(!(image_info->mod->flags & KMOD_FLAG_PERSISTENT))
    {
        kvo_release(image_info);
    }
    return NULL;
}

LIBKERN_DEFINE_PATCHABLE(kern_return_t, kxopen, (const char *path,
                                                 int mode,
                                                 kxld_image_info_t **export_info))
{
    int fd = open(path, O_RDWR);
    if(fd < 0)
    {
        return KERN_FAILURE;
    }
    
    kern_return_t kr = kxopen_with_fd(fd, mode, export_info);
    close(fd);
    return kr;
}

LIBKERN_DEFINE_PATCHABLE(kern_return_t, kxopen_with_fd, (int fd,
                                                         int mode,
                                                         kxld_image_info_t **export_info))
{
    if(fd < 0)
    {
        return KERN_INVALID_ARGUMENT;
    }
    
    os_unfair_lock_lock(&g_kxld_lock);
    if(g_kxld_sealed)
    {
        os_unfair_lock_unlock(&g_kxld_lock);
        return KERN_DENIED;
    }
    
    /* map machO */
    LCMachO *machO = LCMapMachOFromFDRO(dup(fd));
    if(machO == NULL)
    {
        goto out_failure;
    }
    
    /* checking if the kernel says(double meaning x3) this is signed */
    if(!KXValidateCodeSignature(machO))
    {
        LCUnmapMachO(machO);
        goto out_failure;
    }
    
    kxld_image_info_t *image_info = kvo_alloc_fastpath(kxld_image);
    if(image_info == NULL)
    {
        LCUnmapMachO(machO);
        goto out_failure;
    }
    
    if(fcntl(machO->fd, F_GETPATH, image_info->path) != 0)
    {
        LCUnmapMachO(machO);
        kvo_release(image_info);
        goto out_failure;
    }
    
    bool success = KXMapMachOExecutable(machO, mode, image_info);
    LCUnmapMachO(machO);
    if(!success)
    {
        /* sets errno */
        goto out_failure_destroy;
    }
    
    /* we gotta get kmod first */
    if(!KXLocateKmod(image_info))
    {
        goto out_failure_destroy;
    }
    
    /* resolve dependencies versions */
    for(int64_t i = 0; i < (int64_t)image_info->mod->dependency_count; i++)
    {
        {
            kxld_image_info_t *depImageInfo;
            kern_return_t kr = KXGetRegisteredKextForIdentifier(image_info->mod->dependencies[i].identifier, &depImageInfo);
            if(kr != KERN_SUCCESS)
            {
                goto revert;
            }
            
            if(depImageInfo->mod->version < image_info->mod->dependencies[i].min_version ||
               depImageInfo->mod->version > image_info->mod->dependencies[i].max_version)
            {
                goto revert;
            }
            
            /* so the kext knows on what version this dependency is */
            image_info->mod->dependencies[i].min_version = depImageInfo->mod->version;
            image_info->mod->dependencies[i].max_version = depImageInfo->mod->version;
            if(!kvo_retain(depImageInfo))
            {
                goto revert;
            }
            
            continue;
        }
    revert:
        {
            for(; i >= 0; i--)
            {
                kxld_image_info_t *depImageInfo;
                kern_return_t kr = KXGetRegisteredKextForIdentifier(image_info->mod->dependencies[i].identifier, &depImageInfo);
                if(kr != KERN_SUCCESS)
                {
                    kpanic("failed to find previously resolvable dependency that was reference incremented.");
                }
                kvo_release(depImageInfo);
            }
            goto out_failure_destroy;
        }
    }
    image_info->dependenciesResolved = true;
    
    /* apply persistent flag if KXLD_NOCLOSE is set */
    if(mode & KXLD_NOCLOSE)
    {
        image_info->mod->flags |= KMOD_FLAG_PERSISTENT;
    }
    
    /* fixing up kmod and the blobs offsets */
    if(!KXApplyFixups(image_info))
    {
        goto out_failure_destroy;
    }
    
    /* still very unmappable */
    kern_return_t kr = KXRegisterKext(image_info);
    if(kr != KERN_SUCCESS)
    {
        kvo_release(image_info);
        os_unfair_lock_unlock(&g_kxld_lock);
        return kr;
    }
    
    /* now the spicy port with the symbol exports */
    if(!KXRegisterKextExports(image_info))
    {
        goto out_failure_destroy;
    }
    
    if(!KXRegisterObjCImage(image_info))
    {
        goto out_failure_destroy;
    }
    
    /* now resealing */
    if(!KXResealDataConst(image_info))
    {
        goto out_failure_destroy;
    }
    
#if KSURFACE_KEXT_ALLOW_CONSTRUCTORS
    if(!kxld_vtable->KXRunInitializers(image_info))
    {
        goto out_failure_destroy;
    }
#endif /* KSURFACE_KEXT_ALLOW_CONSTRUCTORS */
    
    /* now lets initialize the kext it self */
    if(image_info->mod->init)
    {
        kr = image_info->mod->init();
        if(kr != KERN_SUCCESS)
        {
            klog_log("kextloader", "kext '%s', had a failure initializing: %s", image_info->mod->identifier, mach_error_string(kr));
            goto out_failure_destroy;
        }
        else
        {
            image_info->isInitialized = true;
        }
    }
    
    if(image_info->mod->start)
    {
        pthread_t thread;
        if(pthread_create(&thread, NULL, ksurface_kext_thread, (void*)image_info) != 0)
        {
            klog_log("kextloader", "failed start thread for kext '%s'", image_info->mod->identifier);
            goto out_failure_destroy;
        }
        image_info->isStarted = true;
        pthread_detach(thread);
    }
    else if(!(image_info->mod->flags & KMOD_FLAG_PERSISTENT))
    {
        /* did its modifications, but KMOD_FLAG_PERSISTENT is disabled */
        kvo_release(image_info);
        os_unfair_lock_unlock(&g_kxld_lock);
        return KERN_SUCCESS;
    }
    
    /* done =3 */
    klog_log("kextloader", "successfully initialized kext '%s'", image_info->mod->identifier);
    os_unfair_lock_unlock(&g_kxld_lock);
    if(export_info)
    {
        *export_info = image_info;
    }
    return KERN_SUCCESS;
    
out_failure_destroy:
    kvo_release(image_info);
out_failure:
    os_unfair_lock_unlock(&g_kxld_lock);
    return KERN_FAILURE;
}

LIBKERN_DEFINE_PATCHABLE(kern_return_t, kxclose, (kxld_image_info_t *claimed_image_info))
{
    os_unfair_lock_lock(&g_kxld_lock);
    if(g_kxld_sealed)
    {
        os_unfair_lock_unlock(&g_kxld_lock);
        return KERN_ALREADY_IN_SET;
    }
    klog_log("kextloader", "unloading kext '%s'", claimed_image_info->mod->identifier);
    
    /* finding kext object */
    kxld_image_info_t *image_info = NULL;
    if(KXGetRegisteredKextForIdentifier(claimed_image_info->mod->identifier, &image_info) != KERN_SUCCESS)
    {
        klog_log("kextloader", "couldn't find kext for identifier '%s'", claimed_image_info->mod->identifier);
        return KERN_NOT_FOUND;
    }
    
    if(!(image_info->mod->flags & KMOD_FLAG_PERSISTENT))
    {
        kvo_release(image_info);
    }
    else
    {
        klog_log("kextloader", "kext '%s' is marked as not unloadable", image_info->mod->identifier);
        os_unfair_lock_unlock(&g_kxld_lock);
        return KERN_NOT_SUPPORTED;
    }
    
    klog_log("kextloader", "successfully unloaded kext '%s'", image_info->mod->identifier);
    os_unfair_lock_unlock(&g_kxld_lock);
    return KERN_SUCCESS;
}

LIBKERN_DEFINE_PATCHABLE(kern_return_t, kxld_seal, (void))
{
    os_unfair_lock_lock(&g_kxld_lock);
    if(g_kxld_sealed)
    {
        os_unfair_lock_unlock(&g_kxld_lock);
        return KERN_SUCCESS;
    }
    g_kxld_sealed = true;
    os_unfair_lock_unlock(&g_kxld_lock);
    return KERN_SUCCESS;
}
