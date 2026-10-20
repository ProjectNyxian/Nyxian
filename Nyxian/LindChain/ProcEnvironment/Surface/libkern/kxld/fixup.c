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

#include <LindChain/ProcEnvironment/Surface/libkern/kxld/fixup.h>
#include <LindChain/ProcEnvironment/Surface/libkern/kxld/resolve.h>
#include <LindChain/ProcEnvironment/Surface/libkern/patch.h>
#include <LindChain/ProcEnvironment/Surface/libkern/klog.h>
#include <mach-o/fixup-chains.h>
#include <dlfcn.h>

/* fuck this legacy iOS bullshit, bro lld emits those legacy LC_DYLD_INFO* cmd's ;-; */
uint64_t readULEB(const uint8_t **p,
                  const uint8_t *end)
{
    uint64_t result = 0; int shift = 0;
    while(*p < end)
    {
        uint8_t byte = *(*p)++;
        result |= (uint64_t)(byte & 0x7f) << shift;
        if((byte & 0x80) == 0)
        {
            break;
        }
        shift += 7;
    }
    return result;
}

static int64_t readSLEB(const uint8_t **p, const uint8_t *end)
{
    int64_t result = 0; int shift = 0; uint8_t byte = 0;
    do {
        if(*p >= end)
        {
            break;
        }
        byte = *(*p)++;
        result |= (int64_t)(byte & 0x7f) << shift;
        shift += 7;
    } while (byte & 0x80);
    if(shift < 64 && (byte & 0x40))
    {
        result |= -(1LL << shift);
    }
    return result;
}

static bool KXApplyRebases(kxld_image_info_t *ii,
                           const uint8_t *start,
                           const uint8_t *end,
                           const uint64_t *segBase,
                           uint32_t segCount)
{
    const uint8_t *p = start;
    uint32_t segIdx = 0;
    uint64_t segOff = 0;
    intptr_t slide = ii->slide;
    
    #define REBASE_SLOT()                                              \
        do {                                                           \
            if (segIdx >= segCount) return false;                      \
            uint64_t *slot = (uint64_t *)(segBase[segIdx] + segOff);   \
            *slot += slide;                                            \
        } while (0)
    
    while(p < end)
    {
        uint8_t byte = *p++;
        uint8_t opcode = byte & REBASE_OPCODE_MASK;
        uint8_t imm = byte & REBASE_IMMEDIATE_MASK;
        
        switch(opcode)
        {
            case REBASE_OPCODE_DONE:
                return true;
            case REBASE_OPCODE_SET_TYPE_IMM:
                break;
            case REBASE_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB:
                segIdx = imm;
                segOff = readULEB(&p, end);
                if(segIdx >= segCount)
                {
                    return false;
                }
                break;
            case REBASE_OPCODE_ADD_ADDR_ULEB:
                segOff += readULEB(&p, end);
                break;
            case REBASE_OPCODE_ADD_ADDR_IMM_SCALED:
                segOff += (uint64_t)imm * sizeof(uint64_t);
                break;
            case REBASE_OPCODE_DO_REBASE_IMM_TIMES:
                for(uint32_t i = 0; i < imm; i++)
                {
                    REBASE_SLOT();
                    segOff += sizeof(uint64_t);
                }
                break;
            case REBASE_OPCODE_DO_REBASE_ULEB_TIMES:
            {
                uint64_t count = readULEB(&p, end);
                for(uint64_t i = 0; i < count; i++)
                {
                    REBASE_SLOT();
                    segOff += sizeof(uint64_t);
                }
                break;
            }
            case REBASE_OPCODE_DO_REBASE_ADD_ADDR_ULEB:
                REBASE_SLOT();
                segOff += sizeof(uint64_t) + readULEB(&p, end);
                break;
            case REBASE_OPCODE_DO_REBASE_ULEB_TIMES_SKIPPING_ULEB:
            {
                uint64_t count = readULEB(&p, end);
                uint64_t skip  = readULEB(&p, end);
                for(uint64_t i = 0; i < count; i++)
                {
                    REBASE_SLOT();
                    segOff += sizeof(uint64_t) + skip;
                }
                break;
            }
            default:
                klog_log("kextloader", "unknown rebase opcode 0x%x", opcode);
                return false;
        }
    }
    
    #undef REBASE_SLOT
    return true;
}

static bool KXApplyBinds(kxld_image_info_t *ii,
                         const uint8_t *start,
                         const uint8_t *end,
                         const uint64_t *segBase,
                         uint32_t segCount,
                         bool isLazy)
{
    const uint8_t *p = start;
    const char *symName = NULL;
    bool weak = false;
    int64_t addend = 0;
    uint32_t segIdx = 0;
    uint64_t segOff = 0;
    bool unresolvedAllowed = ii->mod->flags & KMOD_FLAG_ALLOW_UNRESOLVED;
    
#define BIND_SLOT()                                                     \
    do {                                                                \
        if(segIdx >= segCount)                                          \
        {                                                               \
            return false;                                               \
        }                                                               \
        void *addr = KXResolve(symName);                                \
        if(!addr && !weak)                                              \
        {                                                               \
            klog_log("kextloader", "unresolved symbol %s, %s", symName ? symName : "(null)", unresolvedAllowed ? "skipping due to kext compat" : "rejecting, because unresolved"); \
            if(!unresolvedAllowed)                                      \
            {                                                           \
                return false;                                           \
            }                                                           \
            addr = NULL;                                                \
        }                                                               \
        uint64_t *slot = (uint64_t *)(segBase[segIdx] + segOff);        \
        *slot = addr ? (uint64_t)addr + addend : 0;                     \
    } while (0)
    
    while(p < end)
    {
        uint8_t byte = *p++;
        uint8_t opcode = byte & BIND_OPCODE_MASK;
        uint8_t imm = byte & BIND_IMMEDIATE_MASK;
        
        switch(opcode)
        {
            case BIND_OPCODE_DONE:
                if(isLazy)
                {
                    break;
                }
                return true;
            case BIND_OPCODE_SET_DYLIB_ORDINAL_IMM:
                break;
            case BIND_OPCODE_SET_DYLIB_ORDINAL_ULEB:
                readULEB(&p, end);
                break;
            case BIND_OPCODE_SET_DYLIB_SPECIAL_IMM:
                break;
            case BIND_OPCODE_SET_SYMBOL_TRAILING_FLAGS_IMM:
                symName = (const char *)p;
                weak = (imm & BIND_SYMBOL_FLAGS_WEAK_IMPORT) != 0;
                while (p < end && *p) p++;
                if(p < end)
                {
                    p++;
                }
                break;
            case BIND_OPCODE_SET_TYPE_IMM:
                break;
            case BIND_OPCODE_SET_ADDEND_SLEB:
                addend = readSLEB(&p, end);
                break;
            case BIND_OPCODE_SET_SEGMENT_AND_OFFSET_ULEB:
                segIdx = imm;
                segOff = readULEB(&p, end);
                if(segIdx >= segCount)
                {
                    return false;
                }
                break;
            case BIND_OPCODE_ADD_ADDR_ULEB:
                segOff += readULEB(&p, end);
                break;
            case BIND_OPCODE_DO_BIND:
                BIND_SLOT();
                segOff += sizeof(uint64_t);
                break;
            case BIND_OPCODE_DO_BIND_ADD_ADDR_ULEB:
                BIND_SLOT();
                segOff += sizeof(uint64_t) + readULEB(&p, end);
                break;
            case BIND_OPCODE_DO_BIND_ADD_ADDR_IMM_SCALED:
                BIND_SLOT();
                segOff += sizeof(uint64_t) + (uint64_t)imm * sizeof(uint64_t);
                break;
            case BIND_OPCODE_DO_BIND_ULEB_TIMES_SKIPPING_ULEB:
            {
                uint64_t count = readULEB(&p, end);
                uint64_t skip = readULEB(&p, end);
                for(uint64_t i = 0; i < count; i++)
                {
                    BIND_SLOT();
                    segOff += sizeof(uint64_t) + skip;
                }
                break;
            }
            default:
                klog_log("kextloader", "unknown bind opcode 0x%x", opcode);
                return false;
        }
    }
    
    #undef BIND_SLOT
    return true;
}

static bool KXApplyDyldInfoFixups(kxld_image_info_t *image_info,
                                  const struct dyld_info_command *di,
                                  const uint64_t *segBase, uint32_t segCount)
{
    const uint8_t *fb = (const uint8_t *)image_info->base + image_info->sliceOffset;
    
    if(di->rebase_size && !KXApplyRebases(image_info, fb + di->rebase_off, fb + di->rebase_off + di->rebase_size, segBase, segCount))
    {
        return false;
    }
    
    if(di->bind_size && !KXApplyBinds(image_info, fb + di->bind_off, fb + di->bind_off + di->bind_size, segBase, segCount, false))
    {
        return false;
    }
    
    if(di->weak_bind_size && !KXApplyBinds(image_info, fb + di->weak_bind_off, fb + di->weak_bind_off + di->weak_bind_size, segBase, segCount, false))
    {
        return false;
    }
    
    if(di->lazy_bind_size && !KXApplyBinds(image_info, fb + di->lazy_bind_off, fb + di->lazy_bind_off + di->lazy_bind_size, segBase, segCount, true))
    {
        return false;
    }
    
    return true;
}

static bool KXApplyChainedFixups(kxld_image_info_t *image_info,
                                 const struct linkedit_data_command *chainedFixupsCmd)
{
    const uint8_t *fileBase = image_info->base;
    
    const struct dyld_chained_fixups_header *hdr = (const void *)(fileBase + image_info->sliceOffset + chainedFixupsCmd->dataoff);
    const struct dyld_chained_starts_in_image *starts = (const void *)((const uint8_t *)hdr + hdr->starts_offset);
    const struct dyld_chained_import *imports = (const void *)((const uint8_t *)hdr + hdr->imports_offset);
    const char *symbolPool = (const char *)((const uint8_t *)hdr + hdr->symbols_offset);
    bool unresolvedAllowed = image_info->mod->flags & KMOD_FLAG_ALLOW_UNRESOLVED;
    
    for(uint32_t segIdx = 0; segIdx < starts->seg_count; segIdx++)
    {
        uint32_t segInfoOff = starts->seg_info_offset[segIdx];
        if(segInfoOff == 0)
        {
            continue;
        }
        
        const struct dyld_chained_starts_in_segment *seg = (const void *)((const uint8_t *)starts + segInfoOff);
        if(seg->pointer_format != DYLD_CHAINED_PTR_64 && seg->pointer_format != DYLD_CHAINED_PTR_64_OFFSET)
        {
            klog_log("kextloader", "unsupported pointer_format %u in seg %u", seg->pointer_format, segIdx);
            return false;
        }
        
        for(uint16_t pageIdx = 0; pageIdx < seg->page_count; pageIdx++)
        {
            uint16_t start = seg->page_start[pageIdx];
            if(start == DYLD_CHAINED_PTR_START_NONE)
            {
                continue;
            }
            
            uintptr_t pageAddr = (uintptr_t)image_info->slide + seg->segment_offset + (uintptr_t)pageIdx * seg->page_size;
            uintptr_t cursor = pageAddr + start;
            for(;;)
            {
                uint64_t raw = *(uint64_t *)cursor;
                struct dyld_chained_ptr_64_bind *b = (void *)&raw;
                struct dyld_chained_ptr_64_rebase *r = (void *)&raw;
                
                if(b->bind)
                {
                    if(b->ordinal >= hdr->imports_count)
                    {
                        klog_log("kextloader", "bind ordinal %u out of range (%u)", b->ordinal, hdr->imports_count);
                        return false;
                    }
                    const struct dyld_chained_import *imp = &imports[b->ordinal];
                    const char *name = symbolPool + imp->name_offset;
                    void *addr = KXResolve(name);
                    if(!addr && !imp->weak_import)
                    {
                        klog_log("kextloader", "unresolved symbol %s, %s", name?: "(null)", unresolvedAllowed ? "skipping due to kext compat" : "rejecting, because unresolved");
                        if(!unresolvedAllowed)
                        {
                            return false;
                        }
                        addr = NULL;
                    }
                    *(uint64_t *)cursor = addr ? (uint64_t)addr + b->addend : 0;
                }
                else
                {
                    *(uint64_t *)cursor = ((uint64_t)r->target + image_info->slide) | ((uint64_t)r->high8 << 56);
                }
                
                if(r->next == 0)
                {
                    break;
                }
                cursor += (uintptr_t)r->next * 4;
            }
        }
    }
    
    return true;
}

LIBKERN_DEFINE_PATCHABLE(bool, KXApplyFixups, (kxld_image_info_t *image_info))
{
    const struct linkedit_data_command *chainedFixupsCmd = NULL;
    const struct dyld_info_command *dyldInfoCmd = NULL;
    
    uint64_t segBase[64];
    uint32_t segCount = 0;
    
    const uint8_t *ptr = (const uint8_t *)image_info->header + sizeof(struct mach_header_64);
    uint32_t ncmds = image_info->header->ncmds;
    
    for(uint32_t i = 0; i < ncmds; i++)
    {
        const struct load_command *lc = (const struct load_command *)ptr;
        
        switch(lc->cmd)
        {
            case LC_DYLD_CHAINED_FIXUPS:
                chainedFixupsCmd = (const struct linkedit_data_command *)lc;
                break;
            case LC_DYLD_INFO:
            case LC_DYLD_INFO_ONLY:
                dyldInfoCmd = (const struct dyld_info_command *)lc;
                break;
            case LC_SEGMENT_64:
            {
                const struct segment_command_64 *sc = (const struct segment_command_64 *)lc;
                if(segCount < 64)
                {
                    segBase[segCount++] = (uint64_t)image_info->slide + sc->vmaddr;
                }
                break;
            }
        }
        
        ptr += lc->cmdsize;
    }
    
    if(chainedFixupsCmd && !KXApplyChainedFixups(image_info, chainedFixupsCmd))
    {
        return false;
    }
    
    if(dyldInfoCmd && !KXApplyDyldInfoFixups(image_info, dyldInfoCmd, segBase, segCount))
    {
        return false;
    }
    
    /* fixups done */
    return true;
}
