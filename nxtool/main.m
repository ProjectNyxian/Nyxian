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

#define __NXTOOL 1

#include <stdlib.h>
#include <stdio.h>
#import <Foundation/Foundation.h>
#import <LindChain/Utils/Zip.h>
#import <LindChain/ProcEnvironment/Surface/trust/trust.h>
#import <CommonCrypto/CommonCrypto.h>
#include <libgen.h>
#include <sys/stat.h>
#include <assert.h>
#include <mach-o/loader.h>
#include <mach-o/fat.h>

#define APPEND_TAG "NXTR"

static void printUsage(const char *prog)
{
    fprintf(stderr, "Usage: %s <input ipa> <output nipa> <entitlements plist> <private_der_path>\n", prog);
}

int main(int argc, const char * argv[])
{
    /*
     * this tool will be to sign apps with nyxian entitlements (will be .nipa)
     * MARK: this is WIP
     */
    if(argc < 5)
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
    
    NSString *plistPath = [NSString stringWithCString:argv[3] encoding:NSUTF8StringEncoding];
    if(plistPath == nil)
    {
        fprintf(stderr, "error: failed to get plist path\n");
        return 1;
    }
    
    NSString *privDerPath = [NSString stringWithCString:argv[4] encoding:NSUTF8StringEncoding];
    if(privDerPath == nil)
    {
        fprintf(stderr, "error: failed to get priv der path\n");
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
    
    BOOL isKext = NO;
    NSBundle *bundle;
    for(NSString *item in items)
    {
        if([item.pathExtension isEqualToString:@"app"])
        {
            bundle = [NSBundle bundleWithPath:[payloadPath stringByAppendingPathComponent:item]];
            break;
        }
        else if([item.pathExtension isEqualToString:@"kext"])
        {
            bundle = [NSBundle bundleWithPath:[payloadPath stringByAppendingPathComponent:item]];
            isKext = YES;
            break;
        }
    }
    
    if(bundle == nil)
    {
        fprintf(stderr, "error: failed to find app bundle\n");
        [[NSFileManager defaultManager] removeItemAtPath:tmpSpace error:nil];
        return 1;
    }
    
    /* forcing the code directory to be valid */
    if(!isKext && system([[NSString stringWithFormat:@"codesign --force -s - %@", bundle.bundlePath] UTF8String]) != 0)
    {
        fprintf(stderr, "error: failed to force adhoc sign bundle\n");
        [[NSFileManager defaultManager] removeItemAtPath:tmpSpace error:nil];
        return 1;
    }
    
    /* now we'll poc sign */
    NSDictionary *entitlements = [NSDictionary dictionaryWithContentsOfFile:plistPath]?: @{};
    if(trust_nxt2_sign([bundle.executablePath UTF8String], (__bridge CFDictionaryRef)entitlements, true, privDerPath.UTF8String) != KERN_SUCCESS)
    {
        fprintf(stderr, "error: failed to sign app with adhoc NXT2 blob\n");
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
