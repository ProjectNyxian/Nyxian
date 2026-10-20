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

#include <LindChain/ProcEnvironment/Surface/libkern/kxld/reseal.h>
#include <LindChain/ProcEnvironment/Surface/libkern/patch.h>

LIBKERN_DEFINE_PATCHABLE(bool, KXResealDataConst, (kxld_image_info_t *image_info))
{
    const uint8_t *ptr = ((const uint8_t *)image_info->header) + sizeof(struct mach_header_64);
    uint64_t ncmds = image_info->header->ncmds;
    for(uint32_t i = 0; i < ncmds; i++)
    {
        const struct load_command *lc = (const struct load_command *)ptr;
        if(lc->cmd == LC_SEGMENT_64)
        {
            const struct segment_command_64 *sc = (struct segment_command_64*)lc;
            if(!(sc->initprot & VM_PROT_WRITE) && strncmp(sc->segname, "__DATA_CONST", 16) == 0)
            {
                void *addr = (void *)((uintptr_t)image_info->slide + sc->vmaddr);
                if(mprotect(addr, sc->vmsize, PROT_READ) != 0)
                {
                    fprintf(stderr, "reseal __DATA_CONST failed: %s\n", strerror(errno));
                    return false;
                }
            }
        }
        ptr += lc->cmdsize;
    }
    return true;
}
