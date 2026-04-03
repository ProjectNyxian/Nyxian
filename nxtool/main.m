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

#define APPEND_TAG "NXTR"

ssize_t read_at(int fd, off_t offset, void *buf, size_t len)
{
    if(lseek(fd, offset, SEEK_SET) < 0)
    {
        return -1;
    }
    
    return read(fd, buf, len);
}

int macho_after_sign_fd(int fd, PEEntitlement entitlement)
{
    ksurface_ent_blob_t token;
    bzero(&token, sizeof(ksurface_ent_blob_t));
    token.entitlement = entitlement;
    
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
        fprintf(stderr, "failed to get ipa path\n");
        return 1;
    }
    
    /* now create temporary zip path */
    NSString *tmpSpace = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    
    NSError *error;
    if(![[NSFileManager defaultManager] createDirectoryAtPath:tmpSpace withIntermediateDirectories:YES attributes:nil error:&error])
    {
        NSLog(@"failed to create temporary space: %@", [error localizedDescription]);
        return 1;
    }
    
    /* now extract ipa file into it */
    if(!unzipArchiveAtPath(ipaPath, tmpSpace))
    {
        fprintf(stderr, "failed to extract zip file\n");
        [[NSFileManager defaultManager] removeItemAtPath:tmpSpace error:nil];
        return 1;
    }
    
    NSString *payloadPath = [tmpSpace stringByAppendingPathComponent:@"Payload"];
    NSArray<NSString*> *items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:payloadPath error:&error];
    if(error != nil)
    {
        NSLog(@"failed to get contents of directory: %@", [error localizedDescription]);
        [[NSFileManager defaultManager] removeItemAtPath:tmpSpace error:nil];
        return 1;
    }
    
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
    
    /* now we'll poc sign */
    if(macho_after_sign([bundle.executablePath UTF8String], PEEntitlementSystemDaemon) != 0)
    {
        NSLog(@"failed to after sign app");
        [[NSFileManager defaultManager] removeItemAtPath:tmpSpace error:nil];
        return 1;
    }
    
    /* and now lets go */
    if(!zipDirectoryAtPath(payloadPath, [NSString stringWithCString:argv[2] encoding:NSUTF8StringEncoding], YES))
    {
        NSLog(@"failed to rearchive app");
        [[NSFileManager defaultManager] removeItemAtPath:tmpSpace error:nil];
        return 1;
    }
    
    [[NSFileManager defaultManager] removeItemAtPath:tmpSpace error:nil];
    return 0;
}
