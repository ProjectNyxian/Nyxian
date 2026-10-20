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

#include <LindChain/ProcEnvironment/Surface/libkern/kxld/export.h>
#include <LindChain/ProcEnvironment/Surface/libkern/kxld/resolve.h>
#include <LindChain/ProcEnvironment/Surface/libkern/patch.h>

uint64_t readULEB(const uint8_t **p, const uint8_t *end);

static bool KXWalkExportTrie(kxld_image_info_t *image_info,
                             const uint8_t *start,
                             const uint8_t *p,
                             const uint8_t *end,
                             char *prefix,
                             size_t prefixLen,
                             intptr_t slide)
{
    if(p >= end)
    {
        return false;
    }
    
    uint64_t terminalSize = readULEB(&p, end);
    const uint8_t *children = p + terminalSize;
    if(children > end)
    {
        return false;
    }
    
    if(terminalSize > 0)
    {
        uint64_t flags = readULEB(&p, end);
        if(flags & EXPORT_SYMBOL_FLAGS_REEXPORT)
        {
            readULEB(&p, end);
        }
        else if (flags & EXPORT_SYMBOL_FLAGS_STUB_AND_RESOLVER)
        {
            readULEB(&p, end);
            readULEB(&p, end);
        }
        else
        {
            uint64_t addrOffset = readULEB(&p, end);
            prefix[prefixLen] = '\0';
            void *addr = (void *)((uintptr_t)slide + addrOffset);
            if(image_info->mod->flags & KMOD_FLAG_OVERRIDE_CORE)
            {
                KXRegisterExportCore(prefix, addr);
            }
            else
            {
                KXRegisterExport(prefix, addr);
            }
        }
    }
    
    const uint8_t *c = children;
    uint8_t childCount = *c++;
    for(uint8_t i = 0; i < childCount; i++)
    {
        size_t len = 0;
        while(c < end && *c)
        {
            if(prefixLen + len < NAME_MAX - 1)
            {
                prefix[prefixLen + len] = *c;
            }
            c++; len++;
        }
        c++;
        uint64_t childOffset = readULEB(&c, end);
        KXWalkExportTrie(image_info, start, start + childOffset, end, prefix, prefixLen + len, slide);
    }
    return true;
}

LIBKERN_DEFINE_PATCHABLE(bool, KXRegisterKextExports, (kxld_image_info_t *image_info))
{
    const struct linkedit_data_command *exportsTrieCmd = NULL;
    const struct dyld_info_command *dyldInfoCmd    = NULL;
    
    const uint8_t *ptr = (const uint8_t *)image_info->header + sizeof(struct mach_header_64);
    uint32_t ncmds = image_info->header->ncmds;
    for(uint32_t i = 0; i < ncmds; i++)
    {
        const struct load_command *lc = (const struct load_command *)ptr;
        switch(lc->cmd)
        {
            case LC_DYLD_EXPORTS_TRIE:
                exportsTrieCmd = (const struct linkedit_data_command *)lc; break;
            case LC_DYLD_INFO:
            case LC_DYLD_INFO_ONLY:
                dyldInfoCmd = (const struct dyld_info_command *)lc; break;
        }
        ptr += lc->cmdsize;
    }
    
    uint32_t trieOff = 0, trieSize = 0;
    if(exportsTrieCmd)
    {
        trieOff = exportsTrieCmd->dataoff;
        trieSize = exportsTrieCmd->datasize;
    }
    else if(dyldInfoCmd)
    {
        trieOff = dyldInfoCmd->export_off;
        trieSize = dyldInfoCmd->export_size;
    }
    else
    {
        return true;
    }
    if(trieSize == 0)
    {
        return true;
    }
    
    const uint8_t *fb = (const uint8_t *)image_info->base + image_info->sliceOffset;
    const uint8_t *trieStart = fb + trieOff;
    const uint8_t *trieEnd = trieStart + trieSize;
    
    char prefix[NAME_MAX];
    return KXWalkExportTrie(image_info, trieStart, trieStart, trieEnd, prefix, 0, image_info->slide);
}
