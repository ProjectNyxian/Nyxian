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

#include <LindChain/ProcEnvironment/Surface/libkern/kxld/pseudo.h>

kern_return_t kxopen_pseudo(const char *identifier,
                            uint32_t version,
                            uint64_t flags,
                            kxld_image_info_t **out_image_info)
{
    if(identifier == NULL || out_image_info == NULL)
    {
        return KERN_INVALID_ARGUMENT;
    }
    
    kxld_image_info_t *image_info = kvo_alloc_fastpath(kxld_image);
    if(image_info == NULL)
    {
        return KERN_RESOURCE_SHORTAGE;
    }
    
    kinfo_mod_t *pseudo_mod = calloc(1, sizeof(kinfo_mod_t));
    if(pseudo_mod == NULL)
    {
        kvo_release(image_info);
        return KERN_RESOURCE_SHORTAGE;
    }
    image_info->mod = pseudo_mod;
    
    strlcpy((char*)pseudo_mod->identifier, identifier, sizeof(pseudo_mod->identifier));
    pseudo_mod->magic = KSURFACE_KMOD_MAGIC;
    pseudo_mod->version = version;
    pseudo_mod->abi_version = KSURFACE_KMOD_ABI_VERSION;
    pseudo_mod->flags = flags;
    
    *out_image_info = image_info;
    return KERN_SUCCESS;
}
