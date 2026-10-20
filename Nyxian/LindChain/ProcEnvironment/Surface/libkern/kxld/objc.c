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

#include <LindChain/ProcEnvironment/Surface/libkern/kxld/objc.h>
#include <LindChain/ProcEnvironment/Surface/libkern/patch.h>
#include <dlfcn.h>

static bool KXImageHasObjC(kxld_image_info_t *image_info)
{
    const uint8_t *ptr = (const uint8_t *)image_info->header + sizeof(struct mach_header_64);
    uint32_t ncmds = image_info->header->ncmds;
    for(uint32_t i = 0; i < ncmds; i++)
    {
        const struct load_command *lc = (const struct load_command *)ptr;
        if(lc->cmd == LC_SEGMENT_64)
        {
            const struct segment_command_64 *sc = (const struct segment_command_64 *)lc;
            const struct section_64 *sects = (const struct section_64 *)(sc + 1);
            for(uint32_t s = 0; s < sc->nsects; s++)
            {
                if(strncmp(sects[s].sectname, "__objc_", 7) == 0)
                {
                    image_info->safeToUnmap = false;
                    return true;
                }
            }
        }
        ptr += lc->cmdsize;
    }
    return false;
}

typedef void (*objc_map_images_t)(unsigned count, const char * const paths[], const struct mach_header * const mhdrs[]);

LIBKERN_DEFINE_PATCHABLE(bool, KXRegisterObjCImage, (kxld_image_info_t *image_info))
{
    static objc_map_images_t objc_map = NULL;
    static bool probed = false;
    if(!probed)
    {
        objc_map = (objc_map_images_t)dlsym(RTLD_DEFAULT, "_objc_map_images");
        probed = true;
    }
    if(!objc_map)
    {
        return false;
    }
    if(!KXImageHasObjC(image_info))
    {
        return true;
    }
    
    const struct mach_header *mh = (const struct mach_header *)image_info->header;
    const char * const paths[1] = { image_info->path };
    const struct mach_header * const mhdrs[1] = { mh };
    
    objc_map(1, paths, mhdrs);
    return true;
}
