/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 cr4zyengineer

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

#include <stdlib.h>
#include <stdio.h>
#import <Foundation/Foundation.h>
#import <LindChain/Utils/Zip.h>
#import <LindChain/ProcEnvironment/Surface/entitlement.h>
#import <CommonCrypto/CommonCrypto.h>
#include <libgen.h>
#include <sys/stat.h>
#include <assert.h>
#include <mach-o/loader.h>
#include <mach-o/fat.h>

#define APPEND_TAG "NXTRUST"

ssize_t read_at(int fd, off_t offset, void *buf, size_t len)
{
    if(lseek(fd, offset, SEEK_SET) < 0)
    {
        return -1;
    }
    
    return read(fd, buf, len);
}

long find_append_offset(int fd, uint32_t magic, off_t base)
{
    int swap = (magic == MH_CIGAM || magic == MH_CIGAM_64);
    uint32_t ncmds;
    off_t lc_offset;

    if(magic == MH_MAGIC_64 || magic == MH_CIGAM_64)
    {
        struct mach_header_64 hdr;
        read_at(fd, base, &hdr, sizeof(hdr));
        ncmds = swap ? __builtin_bswap32(hdr.ncmds) : hdr.ncmds;
        lc_offset = base + sizeof(hdr);
    }
    else
    {
        struct mach_header hdr;
        read_at(fd, base, &hdr, sizeof(hdr));
        ncmds = swap ? __builtin_bswap32(hdr.ncmds) : hdr.ncmds;
        lc_offset = base + sizeof(hdr);
    }

    for(uint32_t i = 0; i < ncmds; i++)
    {
        struct load_command lc;
        read_at(fd, lc_offset, &lc, sizeof(lc));

        uint32_t cmd     = swap ? __builtin_bswap32(lc.cmd)     : lc.cmd;
        uint32_t cmdsize = swap ? __builtin_bswap32(lc.cmdsize) : lc.cmdsize;

        if(cmd == LC_CODE_SIGNATURE)
        {
            struct linkedit_data_command sigcmd;
            read_at(fd, lc_offset, &sigcmd, sizeof(sigcmd));
            uint32_t dataoff  = swap ? __builtin_bswap32(sigcmd.dataoff)  : sigcmd.dataoff;
            uint32_t datasize = swap ? __builtin_bswap32(sigcmd.datasize) : sigcmd.datasize;
            return (long)(base + dataoff + datasize);
        }

        lc_offset += cmdsize;
    }

    return (long)lseek(fd, 0, SEEK_END);
}

long find_append_offset_for_file(int fd)
{
    uint32_t magic;
    read_at(fd, 0, &magic, sizeof(magic));

    if(magic == FAT_MAGIC || magic == FAT_CIGAM)
    {
        struct fat_header fhdr;
        read_at(fd, 0, &fhdr, sizeof(fhdr));
        uint32_t nfat = __builtin_bswap32(fhdr.nfat_arch);

        long max_end = 0;
        for(uint32_t i = 0; i < nfat; i++)
        {
            struct fat_arch arch;
            off_t arch_offset = sizeof(fhdr) + i * sizeof(arch);
            read_at(fd, arch_offset, &arch, sizeof(arch));
            uint32_t slice_off = __builtin_bswap32(arch.offset);

            uint32_t slice_magic;
            read_at(fd, slice_off, &slice_magic, sizeof(slice_magic));

            long end = find_append_offset(fd, slice_magic, slice_off);
            if(end > max_end)
            {
                max_end = end;
            }
        }
        return max_end;
    }

    return find_append_offset(fd, magic, 0);
}

int macho_after_sign_fd(int fd, PEEntitlement entitlement)
{
    ksurface_ent_blob_t token;
    bzero(&token, sizeof(ksurface_ent_blob_t));

    long offset = find_append_offset_for_file(fd);
    
    if(ftruncate(fd, (off_t)offset) < 0)
    {
        return -1;
    }

    if(lseek(fd, offset, SEEK_SET) < 0)
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


int main(int argc, const char * argv[])
{
    /*
     * this tool will be to sign apps with nyxian entitlements (will be .nipa)
     * MARK: this is WIP
     */
    if(argc < 3)
    {
        fprintf(stderr, "Usage: %s <input ipa> <output nipa>\n", argv[0]);
        return 1;
    }
    
    NSString *ipaPath = [NSString stringWithCString:argv[1] encoding:NSUTF8StringEncoding];
    if(ipaPath == nil)
    {
        fprintf(stderr, "failed\n");
        return 1;
    }
#if DEBUG
    else
    {
        printf("[*] ipa archive located at \"%s\"\n", [ipaPath UTF8String]);
    }
#endif /* DEBUG */
    
    /* now create temporary zip path */
    NSString *tmpSpace = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    
    NSError *error;
    if(![[NSFileManager defaultManager] createDirectoryAtPath:tmpSpace withIntermediateDirectories:YES attributes:nil error:&error])
    {
        NSLog(@"failed to create temporary space: %@", [error localizedDescription]);
        return 1;
    }
#if DEBUG
    else
    {
        printf("[*] created temporary space at \"%s\"\n", [tmpSpace UTF8String]);
    }
#endif /* DEBUG */
    
    /* now extract ipa file into it */
    if(!unzipArchiveAtPath(ipaPath, tmpSpace))
    {
        fprintf(stderr, "failed to extract zip file\n");
        [[NSFileManager defaultManager] removeItemAtPath:tmpSpace error:nil];
        return 1;
    }
#if DEBUG
    else
    {
        printf("[*] extracted ipa file successfully\n");
    }
#endif /* DEBUG */
    
    NSString *payloadPath = [tmpSpace stringByAppendingPathComponent:@"Payload"];
    NSArray<NSString*> *items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:payloadPath error:&error];
    if(error != nil)
    {
        NSLog(@"failed to get contents of directory: %@", [error localizedDescription]);
        [[NSFileManager defaultManager] removeItemAtPath:tmpSpace error:nil];
        return 1;
    }
#if DEBUG
    else
    {
        printf("[*] got content of directory: %s\n", [items.debugDescription UTF8String]);
    }
#endif /* DEBUG */
    
    NSBundle *bundle;
    for(NSString *item in items)
    {
        if([item.pathExtension isEqualToString:@"app"])
        {
            bundle = [NSBundle bundleWithPath:[payloadPath stringByAppendingPathComponent:item]];
            break;
        }
    }
    
    if(bundle == nil)
    {
        NSLog(@"failed to find app bundle");
        [[NSFileManager defaultManager] removeItemAtPath:tmpSpace error:nil];
        return 1;
    }
#if DEBUG
    else
    {
        printf("[*] found app bundle: %s\n", [bundle.debugDescription UTF8String]);
    }
#endif /* DEBUG */
    
    /* now we'll poc sign */
    if(macho_after_sign([bundle.executablePath UTF8String], PEEntitlementSystemApplication) != 0)
    {
        NSLog(@"failed to after sign app");
        [[NSFileManager defaultManager] removeItemAtPath:tmpSpace error:nil];
        return 1;
    }
#if DEBUG
    else
    {
        printf("[*] signed app\n");
    }
#endif /* DEBUG */
    
    /* and now lets go */
    if(!zipDirectoryAtPath(payloadPath, [NSString stringWithCString:argv[2] encoding:NSUTF8StringEncoding], YES))
    {
        NSLog(@"failed to rearchive app");
        [[NSFileManager defaultManager] removeItemAtPath:tmpSpace error:nil];
        return 1;
    }
#if DEBUG
    else
    {
        printf("[*] rearchived app\n");
    }
#endif /* DEBUG */
    
    [[NSFileManager defaultManager] removeItemAtPath:tmpSpace error:nil];
    return 0;
}
