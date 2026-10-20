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

#include <LindChain/ProcEnvironment/Surface/libkern/klog.h>
#include <LindChain/ProcEnvironment/Surface/libkern/kpanic.h>
#include <LindChain/ProcEnvironment/Surface/libkern/kxld/image.h>
#include <LindChain/ProcEnvironment/Surface/libkern/kxld/resolve.h>
#include <os/lock.h>

DEFINE_KVOBJECT_MAIN_EVENT_HANDLER(kxld_image)
{
    /* handle size request */
    if(kvarr == NULL)
    {
        return (int64_t)sizeof(kxld_image_info_t);
    }
    
    /* get our kobj */
    kxld_image_info_t *image_info = (kxld_image_info_t*)kvarr[0];
    
    switch(type)
    {
        case kvObjEventCopy:
        case kvObjEventSnapshot:
            kpanic("attempting to copy or snapshot a kxld image object is illegal");
        case kvObjEventInit:
            image_info->safeToUnmap = true;
            return 0;
        case kvObjEventDeinit:
            if(image_info->mod != NULL)
            {
                if(!(image_info->mod->flags & KMOD_FLAG_PERSISTENT))
                {
                    if(image_info->isStarted && image_info->mod->start)
                    {
                        klog_log("kextloader:unload", "stopping kext '%s'", image_info->mod->identifier);
                        kern_return_t kr = image_info->mod->stop();
                        if(kr != KERN_SUCCESS)
                        {
                            kpanic("kext '%s' failed to stop: %s", image_info->mod->identifier, mach_error_string(kr));
                        }
                    }
                    if(image_info->isInitialized && image_info->mod->deinit)
                    {
                        klog_log("kextloader:unload", "deinitializing kext '%s'", image_info->mod->identifier);
                        kern_return_t kr = image_info->mod->deinit();
                        if(kr != KERN_SUCCESS)
                        {
                            kpanic("kext '%s' failed to deinitialize: %s", image_info->mod->identifier, mach_error_string(kr));
                        }
                    }
                    kern_return_t kr = KXUnregisterKext(image_info);
                    if(kr != KERN_SUCCESS && kr != KERN_NOT_FOUND)
                    {
                        kpanic("kext '%s' failed to unregister: %s", image_info->mod->identifier, mach_error_string(kr));
                    }
                }
                
                /* must come after, cause it may need a dependency to deinitialize */
                if(image_info->dependenciesResolved)
                {
                    klog_log("kextloader:unload", "releasing references of dependencies of kext '%s'", image_info->mod->identifier);
                    for(uint32_t i = 0; i < image_info->mod->dependency_count; i++)
                    {
                        kxld_image_info_t *depImageInfo;
                        kern_return_t kr = KXGetRegisteredKextForIdentifier(image_info->mod->dependencies[i].identifier, &depImageInfo);
                        if(kr != KERN_SUCCESS)
                        {
                            kpanic("failed to find previously resolvable dependency that was reference incremented");
                        }
                        kvo_release(depImageInfo);
                    }
                }
                
                /* then unmap */
                if(image_info->base != NULL && image_info->safeToUnmap)
                {
                    munmap(image_info->base, image_info->len);
                }
            }
            [[fallthrough]];    /* this is C23, fallthrough needs marking lol, apple fix your standard warn flags */
        default:
            return 0;
    }
}
