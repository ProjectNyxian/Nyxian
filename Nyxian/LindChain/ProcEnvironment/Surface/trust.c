/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 mach-port-t

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#import <LindChain/ProcEnvironment/Surface/trust.h>
#import <LindChain/ProcEnvironment/Surface/entitlement.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include <mach-o/loader.h>
#include <mach-o/fat.h>
#include <sys/stat.h>
#import <CommonCrypto/CommonCrypto.h>
#import <mach-o/loader.h>
#import <mach-o/fat.h>

#define APPEND_TAG "NXTR"

#define CSMAGIC_EMBEDDED_SIGNATURE      0xfade0cc0
#define CSMAGIC_CODEDIRECTORY           0xfade0c02
#define CSSLOT_CODEDIRECTORY            0
#define CS_HASHTYPE_SHA256              2
#define CS_HASHTYPE_SHA256_TRUNCATED    3

typedef struct __BlobIndex {
    uint32_t type;
    uint32_t offset;
} CS_BlobIndex;

typedef struct __SuperBlob {
    uint32_t magic;
    uint32_t length;
    uint32_t count;
    CS_BlobIndex index[];
} CS_SuperBlob;

typedef struct __CodeDirectory {
    uint32_t magic;
    uint32_t length;
    uint32_t version;
    uint32_t flags;
    uint32_t hashOffset;
    uint32_t identOffset;
    uint32_t nSpecialSlots;
    uint32_t nCodeSlots;
    uint32_t codeLimit;
    uint8_t  hashSize;
    uint8_t  hashType;
    uint8_t  platform;
    uint8_t  pageSize;
    uint32_t spare2;
    // v0x20200+
    uint32_t scatterOffset;
    uint32_t teamOffset;
    // v0x20300+
    uint32_t spare3;
    uint64_t codeLimit64;
    // v0x20400+
    uint64_t execSegBase;
    uint64_t execSegLimit;
    uint64_t execSegFlags;
} CS_CodeDirectory;

char *cd_hash_of_executable_at_fd(int fd)
{
    struct stat st;
    if(fstat(fd, &st) != 0)
    {
        return NULL;
    }

    size_t size = (size_t)st.st_size;
    if(size == 0)
    {
        return NULL;
    }

    uint8_t *base = mmap(NULL, size, PROT_READ, MAP_PRIVATE, fd, 0);
    if(base == MAP_FAILED)
    {
        return NULL;
    }

    char *result = NULL;
    const uint8_t *mach_header = base;

    uint32_t magic = *(uint32_t *)base;
    if(magic == FAT_CIGAM ||
       magic == FAT_MAGIC ||
       magic == FAT_CIGAM_64 ||
       magic == FAT_MAGIC_64)
    {
        struct fat_header *fat = (struct fat_header *)base;
        uint32_t n_arches = OSSwapBigToHostInt32(fat->nfat_arch);
        struct fat_arch *arches = (struct fat_arch *)(base + sizeof(struct fat_header));
        for(uint32_t i = 0; i < n_arches; i++)
        {
            cpu_type_t cputype = OSSwapBigToHostInt32(arches[i].cputype);
            if(cputype == CPU_TYPE_ARM64)
            {
                mach_header = base + OSSwapBigToHostInt32(arches[i].offset);
                break;
            }
        }
    }

    int is64 = (*(uint32_t *)mach_header == MH_MAGIC_64);
    uint32_t ncmds = is64 ? ((struct mach_header_64 *)mach_header)->ncmds : ((struct mach_header *)mach_header)->ncmds;

    const uint8_t *cmd = mach_header + (is64 ? sizeof(struct mach_header_64) : sizeof(struct mach_header));

    for(uint32_t i = 0; i < ncmds; i++)
    {
        struct load_command *lc = (struct load_command *)cmd;

        if(lc->cmd == LC_CODE_SIGNATURE)
        {
            struct linkedit_data_command *sig_cmd = (struct linkedit_data_command *)cmd;
            CS_SuperBlob *super_blob = (CS_SuperBlob *)(mach_header + sig_cmd->dataoff);

            if(OSSwapBigToHostInt32(super_blob->magic) != CSMAGIC_EMBEDDED_SIGNATURE)
            {
                goto done;
            }

            uint32_t count = OSSwapBigToHostInt32(super_blob->count);
            for(uint32_t j = 0; j < count; j++)
            {
                uint32_t type   = OSSwapBigToHostInt32(super_blob->index[j].type);
                uint32_t offset = OSSwapBigToHostInt32(super_blob->index[j].offset);

                if(type == CSSLOT_CODEDIRECTORY)
                {
                    CS_CodeDirectory *cd = (CS_CodeDirectory *)((uint8_t *)super_blob + offset);

                    if(OSSwapBigToHostInt32(cd->magic) != CSMAGIC_CODEDIRECTORY)
                    {
                        goto done;
                    }
                    
                    uint32_t cd_length = OSSwapBigToHostInt32(cd->length);
                    uint8_t hash_type  = cd->hashType;

                    if(hash_type == CS_HASHTYPE_SHA256 ||
                       hash_type == CS_HASHTYPE_SHA256_TRUNCATED)
                    {
                        unsigned char digest[CC_SHA256_DIGEST_LENGTH];
                        CC_SHA256(cd, cd_length, digest);

                        result = malloc(CC_SHA256_DIGEST_LENGTH * 2 + 1);
                        if(!result) goto done;
                        for(int k = 0; k < CC_SHA256_DIGEST_LENGTH; k++)
                        {
                            snprintf(result + k * 2, 3, "%02x", digest[k]);
                        }
                    }
                    else
                    {
                        unsigned char digest[CC_SHA1_DIGEST_LENGTH];
                        CC_SHA1(cd, cd_length, digest);

                        result = malloc(CC_SHA1_DIGEST_LENGTH * 2 + 1);
                        if(!result) goto done;
                        for(int k = 0; k < CC_SHA1_DIGEST_LENGTH; k++)
                        {
                            snprintf(result + k * 2, 3, "%02x", digest[k]);
                        }
                    }
                    goto done;
                }
            }
        }
        cmd += lc->cmdsize;
    }

done:
    munmap(base, size);
    return result;
}

ssize_t read_at(int fd, off_t offset, void *buf, size_t len)
{
    if(lseek(fd, offset, SEEK_SET) < 0)
    {
        return -1;
    }
    
    return read(fd, buf, len);
}

int macho_after_sign(const char *path,
                     PEEntitlement entitlement)
{
    int fd = open(path, O_RDWR);
    if(fd < 0)
    {
        perror("open");
        return -1;
    }
    
    int retval = macho_after_sign_fd(fd, entitlement);
    fsync(fd);
    close(fd);
    
    return retval;
}

int macho_after_sign_fd(int fd, PEEntitlement entitlement)
{
    char *cdhash = cd_hash_of_executable_at_fd(fd);
    ksurface_ent_blob_t token;
    if(entitlement_token_mach_gen(&token, cdhash, entitlement) != KERN_SUCCESS)
    {
        free(cdhash);
        return -1;
    }
    free(cdhash);

    char tag[4];
    off_t eof = lseek(fd, 0, SEEK_END);
    
    if(eof >= (off_t)(sizeof(ksurface_ent_blob_t) + sizeof(uint32_t) + 4))
    {
        read_at(fd, eof - 4, tag, 4);
        if(memcmp(tag, APPEND_TAG, 4) == 0)
        {
            uint32_t data_len;
            read_at(fd, eof - 4 - sizeof(uint32_t), &data_len, sizeof(uint32_t));
            eof -= (off_t)(data_len + sizeof(uint32_t) + 4);
            ftruncate(fd, eof);
        }
    }

    if(lseek(fd, eof, SEEK_SET) < 0)
    {
        return -1;
    }

    if(write(fd, &token, sizeof(ksurface_ent_blob_t)) != (ssize_t)sizeof(ksurface_ent_blob_t))
    {
        return -1;
    }

    size_t data_len = sizeof(ksurface_ent_blob_t);
    if(write(fd, &data_len, sizeof(uint32_t)) != sizeof(uint32_t))
    {
        return -1;
    }
    if(write(fd, APPEND_TAG, 4) != 4)
    {
        return -1;
    }

    return 0;
}

int macho_read_token(int fd,
                     ksurface_ent_result_t *mach)
{
    bzero(mach, sizeof(ksurface_ent_result_t));
    
    char tag[4];
    uint32_t len;
    
    if(lseek(fd, -4, SEEK_END) < 0)
    {
        return -1;
    }
    if(read(fd, tag, 4) != 4)
    {
        return -1;
    }
    
    if(memcmp(tag, APPEND_TAG, 4) != 0)
    {
        return -1;
    }
    
    if(lseek(fd, -8, SEEK_END) < 0)
    {
        return -1;
    }
    if(read(fd, &len, sizeof(uint32_t)) != sizeof(uint32_t))
    {
        return -1;
    }
    
    if(lseek(fd, -(off_t)(8 + len), SEEK_END) < 0)
    {
        return -1;
    }
    
    if(read(fd, &(mach->blob), len) != (ssize_t)len)
    {
        return -1;
    }
    
    char *hash = cd_hash_of_executable_at_fd(fd);
    if(hash == NULL)
    {
        mach->cdhash_valid = false;
        goto out_no_cdhas;
    }
    else if(strncmp(hash, mach->blob.cdhash, USER_FSIGNATURES_CDHASH_LEN) == 0)
    {
        free(hash);
        mach->cdhash_valid = true;
    out_no_cdhas:
        return 0;
    }
    
    free(hash);
    return -1;
}
