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

static void printUsage(const char *prog)
{
    fprintf(stderr, "Usage: %s <input ipa> <output nipa> [flags...]\n\n", prog);
    fprintf(stderr, "Entitlement flags:\n");
    fprintf(stderr, "  --raw <hex>\n");
    fprintf(stderr, "  --get-task-allowed\n");
    fprintf(stderr, "  --task-for-pid\n");
    fprintf(stderr, "  --proc-enum\n");
    fprintf(stderr, "  --proc-kill\n");
    fprintf(stderr, "  --proc-spawn\n");
    fprintf(stderr, "  --proc-spawn-signed\n");
    fprintf(stderr, "  --proc-elevate\n");
    fprintf(stderr, "  --proc-inherit\n");
    fprintf(stderr, "  --host-manager\n");
    fprintf(stderr, "  --credentials-manager\n");
    fprintf(stderr, "  --ls-start\n");
    fprintf(stderr, "  --ls-stop\n");
    fprintf(stderr, "  --ls-toggle\n");
    fprintf(stderr, "  --ls-get-endpoint\n");
    fprintf(stderr, "  --ls-set-endpoint\n");
    fprintf(stderr, "  --ls-manager\n");
    fprintf(stderr, "  --dyld-hide\n");
    fprintf(stderr, "  --platform\n");
    fprintf(stderr, "  --platform-root\n");
    fprintf(stderr, "\nPreset's:\n");
    fprintf(stderr, "  --preset-user\n");
    fprintf(stderr, "  --preset-system-app\n");
    fprintf(stderr, "  --preset-system-daemon\n");
}

static PEEntitlement parseEntitlementFlags(int argc, const char *argv[], int startIdx)
{
    PEEntitlement result = PEEntitlementNone;
    BOOL gotAny = NO;

    for(int i = startIdx; i < argc; i++)
    {
        const char *arg = argv[i];
        
        if(strcmp(arg, "--raw") == 0)
        {
            if(i + 1 >= argc)
            {
                fprintf(stderr, "error: %s requires a hex value argument\n", arg);
                return (PEEntitlement)-1;
            }
            char *end = NULL;
            uint64_t val = strtoull(argv[++i], &end, 16);
            if(*end != '\0')
            {
                fprintf(stderr, "error: invalid hex value '%s'\n", argv[i]);
                return (PEEntitlement)-1;
            }
            result |= (PEEntitlement)val;
            gotAny = YES;
        }
        else if(strcmp(arg, "--get-task-allowed")       == 0) { result |= PEEntitlementGetTaskAllowed;                   gotAny = YES; }
        else if(strcmp(arg, "--task-for-pid")           == 0) { result |= PEEntitlementTaskForPid;                       gotAny = YES; }
        else if(strcmp(arg, "--proc-enum")              == 0) { result |= PEEntitlementProcessEnumeration;               gotAny = YES; }
        else if(strcmp(arg, "--proc-kill")              == 0) { result |= PEEntitlementProcessKill;                      gotAny = YES; }
        else if(strcmp(arg, "--proc-spawn")             == 0) { result |= PEEntitlementProcessSpawn;                     gotAny = YES; }
        else if(strcmp(arg, "--proc-spawn-signed")      == 0) { result |= PEEntitlementProcessSpawnSignedOnly;           gotAny = YES; }
        else if(strcmp(arg, "--proc-elevate")           == 0) { result |= PEEntitlementProcessElevate;                   gotAny = YES; }
        else if(strcmp(arg, "--proc-inherit")           == 0) { result |= PEEntitlementProcessSpawnInheriteEntitlements; gotAny = YES; }
        else if(strcmp(arg, "--host-manager")           == 0) { result |= PEEntitlementHostManager;                      gotAny = YES; }
        else if(strcmp(arg, "--credentials-manager")    == 0) { result |= PEEntitlementCredentialsManager;               gotAny = YES; }
        else if(strcmp(arg, "--ls-start")               == 0) { result |= PEEntitlementLaunchServicesStart;              gotAny = YES; }
        else if(strcmp(arg, "--ls-stop")                == 0) { result |= PEEntitlementLaunchServicesStop;               gotAny = YES; }
        else if(strcmp(arg, "--ls-toggle")              == 0) { result |= PEEntitlementLaunchServicesToggle;             gotAny = YES; }
        else if(strcmp(arg, "--ls-get-endpoint")        == 0) { result |= PEEntitlementLaunchServicesGetEndpoint;        gotAny = YES; }
        else if(strcmp(arg, "--ls-set-endpoint")        == 0) { result |= PEEntitlementLaunchServicesSetEndpoint;        gotAny = YES; }
        else if(strcmp(arg, "--ls-manager")             == 0) { result |= PEEntitlementLaunchServicesManager;            gotAny = YES; }
        else if(strcmp(arg, "--dyld-hide")              == 0) { result |= PEEntitlementDyldHideLiveProcess;              gotAny = YES; }
        else if(strcmp(arg, "--platform")               == 0) { result |= PEEntitlementPlatform;                         gotAny = YES; }
        else if(strcmp(arg, "--platform-root")          == 0) { result |= PEEntitlementPlatformRoot;                     gotAny = YES; }
        else if(strcmp(arg, "--preset-user")            == 0) { result |= PEEntitlementUserApplication;      gotAny = YES; }
        else if(strcmp(arg, "--preset-system-app")      == 0) { result |= PEEntitlementSystemApplication;    gotAny = YES; }
        else if(strcmp(arg, "--preset-system-daemon")   == 0) { result |= PEEntitlementSystemDaemon;         gotAny = YES; }
        else
        {
            fprintf(stderr, "error: unknown flag '%s'\n", arg);
            return (PEEntitlement)-1;
        }
    }
    
    if(!gotAny)
    {
        fprintf(stderr, "error: no entitlement flags provided\n");
        return (PEEntitlement)-1;
    }
    
    return result;
}

int main(int argc, const char * argv[])
{
    /*
     * this tool will be to sign apps with nyxian entitlements (will be .nipa)
     * MARK: this is WIP
     */
    if(argc < 4)
    {
        printUsage(argv[0]);
        return 1;
    }
    
    NSString *ipaPath = [NSString stringWithCString:argv[1] encoding:NSUTF8StringEncoding];
    if(ipaPath == nil)
    {
        fprintf(stderr, "error: failed to get ipa path\n");
        return 1;
    }
    
    NSString *outPath = [NSString stringWithCString:argv[2] encoding:NSUTF8StringEncoding];
    if(outPath == nil)
    {
        fprintf(stderr, "error: failed to get output path\n");
        return 1;
    }
    
    PEEntitlement entitlement = parseEntitlementFlags(argc, argv, 3);
    if(entitlement == (PEEntitlement)-1)
    {
        printUsage(argv[0]);
        return 1;
    }
    
    unlink([outPath UTF8String]);
    
    /* now create temporary zip path */
    NSString *tmpSpace = [NSTemporaryDirectory() stringByAppendingPathComponent:[[NSUUID UUID] UUIDString]];
    
    NSError *error;
    if(![[NSFileManager defaultManager] createDirectoryAtPath:tmpSpace withIntermediateDirectories:YES attributes:nil error:&error])
    {
        fprintf(stderr, "error: failed to create temporary space: %s\n", [[error localizedDescription] UTF8String]);
        return 1;
    }
    
    /* now extract ipa file into it */
    if(!unzipArchiveAtPath(ipaPath, tmpSpace))
    {
        fprintf(stderr, "error: failed to extract zip file\n");
        [[NSFileManager defaultManager] removeItemAtPath:tmpSpace error:nil];
        return 1;
    }
    
    NSString *payloadPath = [tmpSpace stringByAppendingPathComponent:@"Payload"];
    NSArray<NSString*> *items = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:payloadPath error:&error];
    if(error != nil)
    {
        fprintf(stderr, "error: failed to get contents of directory: %s\n", [[error localizedDescription] UTF8String]);
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
        fprintf(stderr, "error: failed to find app bundle\n");
        [[NSFileManager defaultManager] removeItemAtPath:tmpSpace error:nil];
        return 1;
    }
    
    /* now we'll poc sign */
    if(macho_after_sign([bundle.executablePath UTF8String], entitlement) != 0)
    {
        fprintf(stderr, "error: failed to after sign app\n");
        [[NSFileManager defaultManager] removeItemAtPath:tmpSpace error:nil];
        return 1;
    }
    
    /* and now lets go */
    if(!zipDirectoryAtPath(payloadPath, outPath, YES))
    {
        fprintf(stderr, "error: failed to rearchive app\n");
        [[NSFileManager defaultManager] removeItemAtPath:tmpSpace error:nil];
        return 1;
    }
    
    [[NSFileManager defaultManager] removeItemAtPath:tmpSpace error:nil];
    return 0;
}
