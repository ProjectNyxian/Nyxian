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

#include <LindChain/ProcEnvironment/Surface/libkern/kxld/init.h>
#include <LindChain/ProcEnvironment/Surface/libkern/klog.h>
#include <LindChain/ProcEnvironment/Surface/libkern/patch.h>

typedef void (*kx_init_fn)(int argc, char **argv, char **envp, char **apple, void *vars);

LIBKERN_DEFINE_PATCHABLE(bool, KXRunInitializers, (kxld_image_info_t *image_info))
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
                const struct section_64 *sect = &sects[s];
                uint32_t type = sect->flags & SECTION_TYPE;
                if(type == S_MOD_INIT_FUNC_POINTERS)
                {
                    kx_init_fn *fns = (kx_init_fn *)((uintptr_t)image_info->slide + sect->addr);
                    size_t n = sect->size / sizeof(kx_init_fn);
                    for (size_t k = 0; k < n; k++)
                    {
                        fns[k](0, NULL, NULL, NULL, NULL);
                    }
                }
                else if(type == S_INIT_FUNC_OFFSETS)
                {
                    uint32_t *offs = (uint32_t *)((uintptr_t)image_info->slide + sect->addr);
                    size_t n = sect->size / sizeof(uint32_t);
                    for(size_t k = 0; k < n; k++)
                    {
                        kx_init_fn fn = (kx_init_fn)((uintptr_t)image_info->header + offs[k]);
                        fn(0, NULL, NULL, NULL, NULL);
                    }
                }
            }
        }
        ptr += lc->cmdsize;
    }
    return true;
}
