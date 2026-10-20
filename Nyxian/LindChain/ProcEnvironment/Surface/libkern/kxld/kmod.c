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

#include <LindChain/ProcEnvironment/Surface/libkern/kxld/kmod.h>
#include <LindChain/ProcEnvironment/Surface/libkern/patch.h>

const uint8_t *ksurface_locate_modinfo(const uint8_t *base, size_t size, uint64_t *out_len);

static bool macho_name_eq(const char *field,
                          size_t field_size,
                          const char *want)
{
    size_t have = strnlen(field, field_size);
    size_t want_len = strlen(want);
    return have == want_len && memcmp(field, want, want_len) == 0;
}

static bool range_ok(uint64_t off,
                     uint64_t len,
                     uint64_t total)
{
    return len <= total && off <= total - len;
}

const uint8_t *ksurface_locate_modinfo(const uint8_t *base,
                                       size_t size,
                                       uint64_t *out_len)
{
    if(size < sizeof(struct mach_header_64))
    {
        return NULL;
    }
    
    const struct mach_header_64 *mh = (const struct mach_header_64 *)base;
    if(mh->magic != MH_MAGIC_64)
    {
        return NULL;
    }
    if(mh->filetype != MH_KEXT_BUNDLE)
    {
        return NULL;
    }
    if(!range_ok(sizeof(*mh), mh->sizeofcmds, size))
    {
        return NULL;
    }
    
    const uint8_t *cursor = base + sizeof(*mh);
    const uint8_t *lc_end = cursor + mh->sizeofcmds;
    for(uint32_t i = 0; i < mh->ncmds; i++)
    {
        if((uint64_t)(lc_end - cursor) < sizeof(struct load_command))
        {
            return NULL;
        }
        
        const struct load_command *lc = (const struct load_command *)cursor;
        if(lc->cmdsize < sizeof(struct load_command) ||
           (lc->cmdsize & 0x7) ||
           lc->cmdsize > (uint64_t)(lc_end - cursor))
        {
            return NULL;
        }
        
        if(lc->cmd == LC_SEGMENT_64)
        {
            const struct segment_command_64 *seg = (const struct segment_command_64 *)cursor;
            if(lc->cmdsize < sizeof(*seg))
            {
                return NULL;
            }
            
            if(macho_name_eq(seg->segname, sizeof(seg->segname), SEG_DATA) ||
               macho_name_eq(seg->segname, sizeof(seg->segname), "__DATA_CONST"))
            {
                uint64_t need = sizeof(*seg) + (uint64_t)seg->nsects * sizeof(struct section_64);
                if(lc->cmdsize < need)
                {
                    return NULL;
                }
                
                const struct section_64 *sec = (const struct section_64 *)(cursor + sizeof(*seg));
                
                for(uint32_t j = 0; j < seg->nsects; j++)
                {
                    if(!macho_name_eq(sec[j].sectname, sizeof(sec[j].sectname), "__ksurfacemod"))
                    {
                        continue;
                    }
                    
                    uint32_t type = sec[j].flags & SECTION_TYPE;
                    if(type == S_ZEROFILL || type == S_THREAD_LOCAL_ZEROFILL)
                    {
                        return NULL;
                    }
                    
                    if(!range_ok(sec[j].offset, sec[j].size, size))
                    {
                        return NULL;
                    }
                    
                    *out_len = sec[j].size;
                    return base + sec[j].offset;
                }
            }
        }
        cursor += lc->cmdsize;
    }
    return NULL;
}

LIBKERN_DEFINE_PATCHABLE(bool, KXLocateKmod, (kxld_image_info_t *image_info))
{
    uint64_t sec_len = 0;
    const uint8_t *blob = ksurface_locate_modinfo(image_info->base, image_info->len, &sec_len);
    if(blob == NULL)
    {
        return false;
    }
    
    if(sec_len < sizeof(kinfo_mod_t))
    {
        return false;
    }
    image_info->mod = (kinfo_mod_t*)blob;
    
    if(image_info->mod->magic != KSURFACE_KMOD_MAGIC ||
       image_info->mod->abi_version != KSURFACE_KMOD_ABI_VERSION ||
       strnlen(image_info->mod->identifier, KMOD_MAX_NAME) == KMOD_MAX_NAME)
    {
        return false;
    }
    
    return true;
}
