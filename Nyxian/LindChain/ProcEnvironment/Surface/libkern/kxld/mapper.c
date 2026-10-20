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

#include <LindChain/ProcEnvironment/Surface/libkern/kxld/mapper.h>
#include <LindChain/ProcEnvironment/Surface/libkern/kxld/kxopen.h>
#include <LindChain/ProcEnvironment/Surface/libkern/patch.h>

LIBKERN_DEFINE_PATCHABLE(bool, KXMapMachOExecutable, (LCMachO *machO,
                                                      int mode,
                                                      kxld_image_info_t *image_info))
{
    /* how much memory does this kext need? */
    uintptr_t vmStart = UINT64_MAX;
    uintptr_t vmEnd = 0;
    const uint8_t *ptr = ((const uint8_t *)machO->header) + sizeof(struct mach_header_64);
    uint64_t ncmds = machO->header->ncmds;
    for(uint32_t i = 0; i < ncmds; i++)
    {
        const struct load_command *lc = (const struct load_command *)ptr;
        if(lc->cmd == LC_SEGMENT_64)
        {
            const struct segment_command_64 *sc = (const struct segment_command_64 *)ptr;
            if(sc->vmsize == 0)
            {
                ptr += lc->cmdsize;
                continue;
            }
            vmStart = MIN(vmStart, sc->vmaddr);
            vmEnd = MAX(vmEnd, sc->vmaddr + sc->vmsize);
        }
        ptr += lc->cmdsize;
    }
    
    /* allocating the memory needed by the segments of the kext (aka address space reservation) */
    image_info->len = vmEnd - vmStart;
    image_info->base = mmap(NULL, image_info->len, PROT_NONE, MAP_ANON | MAP_PRIVATE, -1, 0);
    if(image_info->base == MAP_FAILED)
    {
        return false;
    }
    
    /* calculating slide of kext */
    image_info->slide = (intptr_t)image_info->base - (intptr_t)vmStart;
    
    /* now mapping executable memory on iOS the valid way */
    image_info->sliceOffset = (uint8_t*)machO->header - (uint8_t*)machO->map;
    ptr = ((const uint8_t *)machO->header) + sizeof(struct mach_header_64);
    for(uint32_t i = 0; i < ncmds; i++)
    {
        const struct load_command *lc = (const struct load_command *)ptr;
        if(lc->cmd == LC_SEGMENT_64)
        {
            const struct segment_command_64 *sc = (const struct segment_command_64 *)ptr;
            if(sc->vmsize == 0)
            {
                ptr += lc->cmdsize;
                continue;
            }
            
            /* now a lot of math ^^ */
            void *addr = (void *)(sc->vmaddr + image_info->slide);
            off_t fileOff = image_info->sliceOffset + sc->fileoff;
            int prot = 0;
            if(sc->initprot & VM_PROT_READ)
            {
                prot |= PROT_READ;
            }
            if(sc->initprot & VM_PROT_WRITE)
            {
                prot |= PROT_WRITE;
            }
            if(sc->initprot & VM_PROT_EXECUTE)
            {
                /* executable mappings cannot be writable */
                prot |= PROT_EXEC;
                prot &= ~PROT_WRITE;
            }
            
            /*
             * AMFI allows MAP_PRIVATE and MAP_SHARED on executable pages.
             * interesting would be if you could do a partial mapping.
             */
            int flags = 0;
            if(mode & KXLD_MAP_PRIVATE)
            {
                flags = MAP_PRIVATE;
            }
            else
            {
                flags = (sc->initprot & VM_PROT_WRITE) ? MAP_PRIVATE : MAP_SHARED;
            }
            flags |= MAP_FIXED;
            
            /* the everything part */
            if(sc->filesize > 0)
            {
                /*
                 * it doesn't matter where you map something, it will still be
                 * executable, even if the executable is not entirely mapped.
                 * which is crazy.
                 */
                void *r = mmap(addr, sc->filesize, prot, flags, machO->fd, fileOff);
                if(r == MAP_FAILED)
                {
                    return false;
                }
            }
            
            /* the bss part */
            size_t pageSize = vm_page_size;
            if(sc->vmsize > sc->filesize)
            {
                /* I love tails >~< */
                uintptr_t fileEnd = (uintptr_t)addr + sc->filesize;
                uintptr_t bssStart = (fileEnd + pageSize - 1) & ~(pageSize - 1);
                uintptr_t bssEnd = (uintptr_t)addr + sc->vmsize;
                bssEnd = (bssEnd + pageSize - 1) & ~(pageSize - 1);
                
                if(bssEnd > bssStart)
                {
                    void *r = mmap((void *)bssStart, bssEnd - bssStart, prot, MAP_PRIVATE | MAP_FIXED | MAP_ANON, -1, 0);
                    if(r == MAP_FAILED)
                    {
                        return false;
                    }
                }
            }
        }
        ptr += lc->cmdsize;
    }
    
    image_info->header = image_info->base;
    
    return true;
}
