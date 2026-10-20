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

#import <LindChain/ProcEnvironment/KextLoader/PEKextLoader.h>
#import <LindChain/ProcEnvironment/KextLoader/PEKext.h>
#import <LindChain/ProcEnvironment/Surface/fs/fs.h>
#import <LindChain/ProcEnvironment/Surface/libkern/kxld/image.h>
#import <LindChain/ProcEnvironment/Surface/libkern/kxld/kxopen.h>
#import <LindChain/ProcEnvironment/Surface/libkern/klog.h>

static BOOL PEKextIsVersionInBetweenMinMax(NSString *version,
                                           NSString *minVersion,
                                           NSString *maxVersion)
{
    if(minVersion)
    {
        NSComparisonResult minCheck = [version compare:minVersion options:NSNumericSearch];
        if(minCheck == NSOrderedAscending)
        {
            return NO;
        }
    }
    
    if(maxVersion)
    {
        NSComparisonResult maxCheck = [version compare:maxVersion options:NSNumericSearch];
        if(maxCheck == NSOrderedDescending)
        {
            return NO;
        }
    }
    
    return YES;
}

static NSUInteger PEKextPriority(PEKext *kext)
{
    if(kext.flags & KMOD_FLAG_OVERRIDE_CORE)
    {
        return 0;
    }
    return 2;
}

BOOL PEKextLoaderLoad(NSMutableString *errorString)
{
    NSError *error;
    NSArray<NSString*> *kextPaths = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:kextFSRoot error:&error];
    if(kextPaths == nil)
    {
        if(errorString)
        {
            if(errorString.length > 0)
            {
                [errorString appendString:@"\n\n"];
            }
            [errorString appendFormat:@"Couldn't find kexts in kextfs: \"%@\".", error.localizedDescription];
        }
        return false;
    }
    
    /* getting kexts initially */
    NSMutableArray<PEKext*> *allKexts = [NSMutableArray array];
    [allKexts addObject:[PEKext appleIOSKext]];
    [allKexts addObject:[PEKext ksurfaceMainKext]];
    for(NSString *kextPath in kextPaths)
    {
        NSString *fullKextPath = [kextFSRoot stringByAppendingPathComponent:kextPath];
        PEKext *kext = [[PEKext alloc] initWithPath:fullKextPath];
        if(kext == nil)
        {
            if(errorString)
            {
                if(errorString.length > 0)
                {
                    [errorString appendString:@"\n\n"];
                }
                [errorString appendFormat:@"Failed to parse kext for path: %@.", fullKextPath];
            }
            continue;
        }
        if(!kext.isEnabled)
        {
            continue;
        }
        [allKexts addObject:kext];
    }
    
    /* intiliting map */
    NSMutableDictionary<NSString *, PEKext *> *kextMap = [NSMutableDictionary dictionary];
    for(PEKext *kext in allKexts)
    {
        kextMap[kext.bundleID] = kext;
    }
    
    BOOL removedAny;
    do
    {
        removedAny = NO;
        NSArray *currentBundleIDs = [kextMap.allKeys copy];
        
        for(NSString *bundleID in currentBundleIDs)
        {
            PEKext *kext = kextMap[bundleID];
            BOOL dependenciesSatisfied = YES;
            
            for(PEDependency *dep in kext.dependencies)
            {
                PEKext *resolvedDep = kextMap[dep.bundleID];
                if(!resolvedDep)
                {
                    if(errorString)
                    {
                        if(errorString.length > 0)
                        {
                            [errorString appendString:@"\n\n"];
                        }
                        [errorString appendFormat:@"Kext '%@' requires kext with '%@', but it is entirely missing from the kexts.", kext.bundleID, dep.bundleID];
                    }
                    dependenciesSatisfied = NO;
                    break;
                }
                
                if(!PEKextIsVersionInBetweenMinMax(resolvedDep.version, dep.minVersion, dep.maxVersion))
                {
                    if(errorString)
                    {
                        if(errorString.length > 0)
                        {
                            [errorString appendString:@"\n\n"];
                        }
                        [errorString appendFormat:@"Kext '%@' requires kext '%@' on version %@ up to %@, but the installed version of '%@' is version %@.", kext.bundleID, dep.bundleID, dep.minVersion, dep.maxVersion, dep.bundleID, resolvedDep.version];
                    }
                    dependenciesSatisfied = NO;
                    break;
                }
            }
            
            if(!dependenciesSatisfied)
            {
                [kextMap removeObjectForKey:bundleID];
                removedAny = YES;
            }
        }
    } while(removedAny);
    
    NSMutableDictionary<NSString*,NSNumber*> *inDegree = [NSMutableDictionary dictionary];
    NSMutableDictionary<NSString*,NSMutableArray<NSString*>*> *dependents = [NSMutableDictionary dictionary];
    
    for(PEKext *kext in kextMap.allValues)
    {
        inDegree[kext.bundleID] = @(kext.dependencies.count);
        for(PEDependency *dep in kext.dependencies)
        {
            if(!dependents[dep.bundleID])
            {
                dependents[dep.bundleID] = [NSMutableArray array];
            }
            [dependents[dep.bundleID] addObject:kext.bundleID];
        }
    }
    
    /* kexts without dependencies shall load first */
    NSMutableArray<PEKext *> *queue = [NSMutableArray array];
    for(NSString *bundleID in inDegree)
    {
        if([inDegree[bundleID] integerValue] == 0)
        {
            [queue addObject:kextMap[bundleID]];
        }
    }
    
    /* the final load order */
    NSMutableArray<PEKext *> *loadOrder = [NSMutableArray array];
    while(queue.count > 0)
    {
        NSUInteger bestIdx = 0;
        for(NSUInteger i = 1; i < queue.count; i++)
        {
            if(PEKextPriority(queue[i]) < PEKextPriority(queue[bestIdx]))
            {
                bestIdx = i;
            }
        }
        PEKext *current = queue[bestIdx];
        [queue removeObjectAtIndex:bestIdx];
        [loadOrder addObject:current];
        NSArray *dependentIDs = dependents[current.bundleID];
        for(NSString *depID in dependentIDs)
        {
            NSInteger count = [inDegree[depID] integerValue] - 1;
            inDegree[depID] = @(count);
            if(count == 0)
            {
                [queue addObject:kextMap[depID]];
            }
        }
    }
    
    if(loadOrder.count != kextMap.count)
    {
        return nil;
    }
    
    klog_log("kextloader", "kernel extension load chain:");
    for(PEKext *kext in loadOrder)
    {
        klog_log("kextloader", "%@ %@ (abi %u, flags 0x%llx)", kext.bundleID, kext.version, kext.abi_version, (unsigned long long)kext.flags);
        for(PEDependency *dependency in kext.dependencies)
        {
            klog_log("kextloader", "  needs %@ [%@ .. %@]", dependency.bundleID, dependency.minVersion, dependency.maxVersion);
        }
    }
    
    NSMutableSet<NSString *> *failed = [NSMutableSet set];
    for(PEKext *kext in loadOrder)
    {
        if([kext.bundleID isEqualToString:@"ksurface"] ||
           [kext.bundleID isEqualToString:@"com.apple.iphoneos"])   /* we are not iOS, just image it is there */
        {
            /* we are ksurface */
            continue;
        }
        
        NSString *blockedBy = nil;
        for(PEDependency *dep in kext.dependencies)
        {
            if([failed containsObject:dep.bundleID])
            {
                blockedBy = dep.bundleID;
                break;
            }
        }
        
        if(blockedBy)
        {
            [failed addObject:kext.bundleID];
            if(errorString)
            {
                if(errorString.length > 0)
                {
                    [errorString appendString:@"\n\n"];
                }
                [errorString appendFormat:@"Kext '%@' was not loaded because its dependency '%@' failed to load.", kext.bundleID, blockedBy];
            }
            continue;
        }
        
        kern_return_t kr = [kext load];
        if(kr != KERN_SUCCESS)
        {
            [failed addObject:kext.bundleID];
            if(errorString)
            {
                if(errorString.length > 0)
                {
                    [errorString appendString:@"\n\n"];
                }
                [errorString appendFormat:@"Kext '%@' failed to load: %s.", kext.bundleID, mach_error_string(kr)];
            }
        }
    }
    
    kxld_seal();
    
    return YES;
}
