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

#include <LindChain/ProcEnvironment/Surface/cache/shimcache.h>
#include <LindChain/ProcEnvironment/Surface/fs/fs.h>
#include <LindChain/ProcEnvironment/Surface/fs/mount.h>
#include <stdio.h>
#include <os/lock.h>
#import <Foundation/Foundation.h>
#import <MobileDevelopmentKit/MobileDevelopmentKit.h>
#import <LindChain/IDEFoundation/NXBootstrap.h>
#import <LindChain/IDEFoundation/NXProject.h>
#import <LindChain/ProcEnvironment/Surface/libkern/klog.h>
#import <LindChain/ProcEnvironment/Utils/vnode.h>
#import <LindChain/ProcEnvironment/LiveContainer/LCUtils.h>
#include <LindChain/ProcEnvironment/Surface/libkern/patch.h>

static os_unfair_lock g_shimcache_lock = OS_UNFAIR_LOCK_INIT;

static shimcache_segment_t *g_shimcache_seg;
static int g_shimcache_seg_cnt = 0;

LIBKERN_DEFINE_PATCHABLE(kern_return_t, ksurface_shimcache_append_code, (CCFileType fileType,
                                                                         const char *code))
{
    os_unfair_lock_lock(&g_shimcache_lock);
    
    /* we need a slot */
    int index = g_shimcache_seg_cnt++;
    void *newptr = realloc(g_shimcache_seg, sizeof(shimcache_segment_t) * g_shimcache_seg_cnt);
    if(newptr)
    {
        g_shimcache_seg = newptr;
    }
    else
    {
        g_shimcache_seg_cnt--;
        os_unfair_lock_unlock(&g_shimcache_lock);
        return KERN_FAILURE;
    }
    
    /* now we fill the slot */
    g_shimcache_seg[index].code = strdup(code);
    if(g_shimcache_seg[index].code == NULL)
    {
        g_shimcache_seg_cnt--;
        os_unfair_lock_unlock(&g_shimcache_lock);
        return KERN_FAILURE;
    }
    g_shimcache_seg[index].fileType = fileType;
    
    os_unfair_lock_unlock(&g_shimcache_lock);
    return KERN_SUCCESS;
}

LIBKERN_DEFINE_PATCHABLE(kern_return_t, ksurface_shimcache_build, (void))
{
    os_unfair_lock_lock(&g_shimcache_lock);
    NSURL *shimcacheBuildURL = [[NSURL fileURLWithPath:NSHomeDirectory()] URLByAppendingPathComponent:@"/Library/Shimcache.builder"];
    [[NSFileManager defaultManager] removeItemAtURL:shimcacheBuildURL error:nil];
    if(![[NSFileManager defaultManager] createDirectoryAtURL:shimcacheBuildURL withIntermediateDirectories:YES attributes:@{} error:nil])
    {
        klog_log("shimcache:emit:error", "couldn't create build directory");
        os_unfair_lock_unlock(&g_shimcache_lock);
        return KERN_FAILURE;
    }
    
    /* write out code files */
    NSMutableArray<NSString*> *codeFiles = [NSMutableArray array];
    for(int index = 0; index < g_shimcache_seg_cnt; index++)
    {
        NSString *fileExtension;
        switch(g_shimcache_seg[index].fileType)
        {
            case kCCFileTypeC:
                fileExtension = @"c";
                break;
            case kCCFileTypeCXX:
                fileExtension = @"cpp";
                break;
            case kCCFileTypeObjC:
                fileExtension = @"m";
                break;
            case kCCFileTypeObjCXX:
                fileExtension = @"mm";
                break;
            default:
                klog_log("shimcache:emit:error", "file type %d is not supported yet", g_shimcache_seg[index].fileType);
                goto just_continue;
        }
        
        {
            NSURL *codeFileURL = [shimcacheBuildURL URLByAppendingPathComponent:[[[NSUUID UUID] UUIDString] stringByAppendingPathExtension:fileExtension]];
            NSString *codeString = @(g_shimcache_seg[index].code);
            if(codeFileURL && codeString)
            {
                [codeString writeToURL:codeFileURL atomically:YES encoding:NSUTF8StringEncoding error:nil];
                [codeFiles addObject:codeFileURL.path];
            }
        }
        
    just_continue:
        continue;
    }
    
    if([codeFiles count] <= 0)
    {
        klog_log("shimcache:emit", "nothing to build", codeFiles);
        os_unfair_lock_unlock(&g_shimcache_lock);
        return KERN_SUCCESS;
    }
    
    /* now we need to compile them together to one shimcache */
    NSString *shimCacheDylib = [[[[NXBootstrap shared] rootURL] URLByAppendingPathComponent:@"/mntfs/bootfs/rtpatch"] path];
    
    NSMutableArray<NSString*> *driverFlags = [NSMutableArray array];
    [driverFlags addObjectsFromArray:[NXProjectConfig sdkCompilerFlags]];
    [driverFlags addObject:@"-target"];
    [driverFlags addObject:@"apple-arm64-ios18.4"];
    [driverFlags addObjectsFromArray:codeFiles];
    [driverFlags addObject:@"-o"];
    [driverFlags addObject:shimCacheDylib];
    [driverFlags addObject:@"-shared"];
    [driverFlags addObject:@"-ObjC"];
    [driverFlags addObject:@"-fobjc-arc"];
    [driverFlags addObject:@"-fmodules"];
    [driverFlags addObject:@"-Wl,-undefined,dynamic_lookup"];
    
    MDKDriver *driver = [MDKDriver driverWithArguments:driverFlags withType:MDKDriverTypeClang];
    if(driver == NULL)
    {
        klog_log("shimcache:emit", "couldn't get driver object", driverFlags);
        os_unfair_lock_unlock(&g_shimcache_lock);
        return KERN_FAILURE;
    }
    
    klog_log("shimcache:emit", "building shims into shimcache");
    NSArray<MDKJob*> *jobs = [driver generateJobs];
    for(MDKJob *job in jobs)
    {
        NSArray<MDKDiagnostic*> *outDiagnostic = nil;
        NSString *mainSourceFile = nil;
        BOOL success = [job executeJobWithOutDiagnostics:&outDiagnostic withOutMainSource:&mainSourceFile];
        if(outDiagnostic.count > 0)
        {
            klog_log("shimcache:emit:diagnostic", "%@:", mainSourceFile);
        }
        for(MDKDiagnostic *diagnostic in outDiagnostic)
        {
            const char *domain = NULL;
            switch(diagnostic.level)
            {
                case MDKDiagnosticLevelNote:
                    domain = "shimcache:emit:diagnostic:note";
                    break;
                case MDKDiagnosticLevelRemark:
                    domain = "shimcache:emit:diagnostic:remark";
                    break;
                case MDKDiagnosticLevelWarning:
                    domain = "shimcache:emit:diagnostic:warning";
                    break;
                case MDKDiagnosticLevelError:
                    domain = "shimcache:emit:diagnostic:error";
                    break;
                case MDKDiagnosticLevelFatal:
                    domain = "shimcache:emit:diagnostic:fatal";
                    break;
                default:
                    domain = "shimcache:emit:diagnostic:unknown";
                    break;
            }
            klog_log(domain, "    %@", diagnostic.message);
        }
        if(!success)
        {
            klog_log("shimcache:emit:error", "%@:", mainSourceFile);
            for(MDKDiagnostic *diagnostic in outDiagnostic)
            {
                klog_log("shimcache:emit:error", "    %@", diagnostic.message);
            }
            os_unfair_lock_unlock(&g_shimcache_lock);
            return KERN_FAILURE;
        }
    }
    [[NSFileManager defaultManager] removeItemAtURL:shimcacheBuildURL error:nil];
    
    /* sign it */
    if(![LCUtils signMachOWithoutPatchAtURL:[NSURL fileURLWithPath:shimCacheDylib]])
    {
        klog_log("shimcache:emit", "couldn't sign shimcache");
        os_unfair_lock_unlock(&g_shimcache_lock);
        [[NSFileManager defaultManager] removeItemAtPath:shimCacheDylib error:nil];
        return KERN_SUCCESS;
    }
    else
    {
        klog_log("shimcache:emit", "signed shimcache", driverFlags);
    }
    
    if(!vnode_refresh_with_path(shimCacheDylib.UTF8String))
    {
        klog_log("shimcache:emit", "couldn't refresh vnode of shimcache");
        os_unfair_lock_unlock(&g_shimcache_lock);
        [[NSFileManager defaultManager] removeItemAtPath:shimCacheDylib error:nil];
        return KERN_SUCCESS;
    }
    else
    {
        klog_log("shimcache:emit", "refreshed vnode of shimcache", driverFlags);
    }
    
    [[NSFileManager defaultManager] setAttributes:@{
        NSFilePosixPermissions: @(0555),
    } ofItemAtPath:shimCacheDylib error:nil];
    
    os_unfair_lock_unlock(&g_shimcache_lock);
    return KERN_SUCCESS;
}
