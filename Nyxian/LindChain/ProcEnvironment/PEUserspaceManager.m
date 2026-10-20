/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2025 - 2026 emexlab
 Copyright (C) 2026 ruri1208

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

#import <LindChain/ProcEnvironment/Surface/libkern/klog.h>
#import <LindChain/ProcEnvironment/Surface/libkern/kpanic.h>
#import <LindChain/ProcEnvironment/Surface/cache/shimcache.h>
#import <LindChain/ProcEnvironment/Surface/fs/fs.h>
#import <LindChain/ProcEnvironment/Surface/fs/preserver.h>
#import <LindChain/ProcEnvironment/Surface/libkern/kxld/kxopen.h>
#import <LindChain/ProcEnvironment/Surface/cache/patchcache.h>
#import <LindChain/ProcEnvironment/PEUserspaceManager.h>
#import <LindChain/ProcEnvironment/PEExtension.h>
#import <LindChain/ProcEnvironment/PEProcessManager.h>
#import <LindChain/ProcEnvironment/PELaunchServiceManager.h>
#import <LindChain/ProcEnvironment/PEBootstrapRegistry.h>
#import <LindChain/ProcEnvironment/KextLoader/PEKextLoader.h>
#import <LindChain/IDEFoundation/NXBootstrap.h>
#import <Nyxian-Swift.h>

@implementation PEUserspaceManager {
    os_unfair_lock _lock;
    atomic_flag _bootOnceFlag;
    atomic_bool _bootSuccessful;
    atomic_bool _launchServiceManagerStable;
}

@dynamic isBooted;
@dynamic isLaunchServiceManagerStable;

+ (instancetype)shared
{
    static PEUserspaceManager *shared;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        shared = [[PEUserspaceManager alloc] init];
    });
    return shared;
}

- (BOOL)isBooted
{
    return atomic_load_explicit(&_bootSuccessful, memory_order_acquire);
}

- (BOOL)isLaunchServiceManagerStable
{
    return atomic_load_explicit(&_launchServiceManagerStable, memory_order_acquire);
}

- (instancetype)init
{
    static atomic_flag once = ATOMIC_FLAG_INIT;
    if(atomic_flag_test_and_set(&once))
    {
        kpanic("This class may only be initilized once");
    }
    
    self = [super init];
    if(self)
    {
        _lock = OS_UNFAIR_LOCK_INIT;
        atomic_flag_clear(&_bootOnceFlag);
        atomic_store_explicit(&_bootSuccessful, false, memory_order_release);
        atomic_store_explicit(&_launchServiceManagerStable, false, memory_order_release);
        _mode = kPEUserspaceModeDefault;
    }
    return self;
}

- (void)bootWithKextLoadingEnabled:(BOOL)enabled
{
    const char *domain = "PEUserspaceManager:boot";
    
    /* boot shall only happen once */
    if(atomic_flag_test_and_set(&_bootOnceFlag))
    {
        kpanic("boot called twice");
    }
    
    os_unfair_lock_lock(&_lock);
    
    /* extension must be available */
    if(PEGetLiveProcessBundle() == NULL ||
       !PEExtensionHasGetTaskAllowed())
    {
        klog_log(domain, "Cannot spin up anything, extension is malformed");
        os_unfair_lock_unlock(&_lock);
        return;
    }
    
    /* now we can spin up that baby (micro kernel) =3 */
    ksurface_kinit();
    
    if(enabled)
    {
        NSMutableString *string = [[NSMutableString alloc] init];
        klog_log(domain, "kextloader %s", PEKextLoaderLoad(string) ? "[ok]" : "[fail]");
        NSString *message = [string copy];
        if(message.length > 0)
        {
            [NXAlertDiagnosticPresenter notifyUserWithLevel:NXAlertDiagnosticPresenterLevelError withMessage:message withDelay:1.0];
        }
    }
    else
    {
        klog_log(domain, "kextloader [disabled]");
        /* seal so nobody can load them anyways */
        kxld_seal();
    }
    
    /* now the actual userspace */
    Class UserspaceBootChain[] = {
        [PEProcessManager class],
        [PEBootstrapRegistry class],
        [PELaunchServiceManager class],
    };
    
    for(size_t index = 0; index < sizeof(UserspaceBootChain) / sizeof(Class); index++)
    {
        Class class = UserspaceBootChain[index];
        if([class shared] != nil)
        {
            klog_log(domain, "%@ [ok]", class);
        }
        else
        {
            kpanic("%s [failed]", [NSStringFromClass(class) UTF8String]);
        }
    }
    klog_log(domain, "%@ [ok]", [self class]);
    os_unfair_lock_unlock(&self->_lock);
    
    /* shimcache needs to exist before the Userspace can truly spin up */
    dispatch_async(dispatch_queue_create("org.emexlabs.nyxian.noblock.userspacemanager", DISPATCH_QUEUE_SERIAL), ^{
        [[NXBootstrap shared] waitTillDoneNoButton];
        
        os_unfair_lock_lock(&self->_lock);
        if(ksurface_shimcache_build() != KERN_SUCCESS)
        {
            kpanic("shimcache build failed");
        }
        klog_log(domain, "shimcache [ok]");
        
        if(ksurface_patchcache_emit() != KERN_SUCCESS)
        {
            kpanic("patchfinder emission failed");
        }
        klog_log(domain, "patchfinder [ok]");
        
        /* spinning up the launch services */
        [[PELaunchServiceManager shared] reloadAllEntries];
        
        /* mark current boot as successful */
        atomic_store_explicit(&self->_launchServiceManagerStable, true, memory_order_release);
        atomic_store_explicit(&self->_bootSuccessful, true, memory_order_release);
        os_unfair_lock_unlock(&self->_lock);
    });
}

- (BOOL)rebootUserspaceWithType_nolock:(PEUserspaceRebootType)type
{
    if(!atomic_load_explicit(&_bootSuccessful, memory_order_acquire))
    {
        return NO;
    }
    
    const char *domain = "PEUserspaceManager:reboot";
    
    /* TODO: prevent spawns from happening, deny any new spawns too */
    klog_log(domain, "aquiring proctil lock");
    if(proctil(kProctilActionLock) != KERN_SUCCESS)
    {
        klog_log(domain, "userspace reboot failed, lock couldn't be claimed");
        return NO;
    }
    
    klog_log(domain, "invalidating all launch service entries in registry");
    [[PELaunchServiceManager shared] invalidateAllEntries];    /* causes reignition to fail in launch services, so killing will not automatically restart them */
    
    klog_log(domain, "killing all running processes");
    [[PEProcessManager shared] killAllRunningProcesses];
    
    klog_log(domain, "releasing proctil lock");
    proctil(kProctilActionUnlock);
    
    klog_log(domain, "reloading daemons");
    switch(type)
    {
        case kPEUserspaceRebootTypeDefault:
            _mode = kPEUserspaceModeDefault;
            break;
        case kPEUserspaceRebootTypeMinimal:
            _mode = kPEUserspaceModeMinimal;
            break;
        default:
            _mode = kPEUserspaceModeEmpty;
            break;
    }
    [self reloadDaemons_nolock];
    
    klog_log(domain, "userspace rebooted successfully");
    return YES;
}

- (BOOL)rebootUserspace
{
    os_unfair_lock_lock(&_lock);
    BOOL success = [self rebootUserspaceWithType_nolock:kPEUserspaceRebootTypeDefault];
    os_unfair_lock_unlock(&_lock);
    return success;
}

- (BOOL)restore
{
    if(!atomic_load_explicit(&_bootSuccessful, memory_order_acquire))
    {
        return NO;
    }
    
    const char *domain = "PEUserspaceManager:restore";
    
    os_unfair_lock_lock(&_lock);
    goto first;
    
retry_fail: /* a retry shall not happen, happens tho if something goes wrong */
    klog_log(domain, "failed to restore, reattempt restore");
    
first:
    {
        /* needs to be in minimal userspace boot mode to safely begin restoring the container through containerd */
        klog_log(domain, "rebooting userspace into empty mode");
        [self rebootUserspaceWithType_nolock:kPEUserspaceRebootTypeEmpty];
        
        /* now we have to restore the default hostname */
        klog_log(domain, "restoring hostname");
        ksurface_sethostname(@"localhost");
        
        klog_log(domain, "restoring code signature key pair");
        uint8_t *new_priv = NULL, *new_pub = NULL;
        size_t new_priv_len = 0, new_pub_len = 0;
        
        if(!get_kernel_ec_key(&new_priv, &new_priv_len, &new_pub, &new_pub_len))
        {
            goto retry_fail;
        }
        
        int ret = store_kernel_key(new_priv, new_priv_len, new_pub, new_pub_len);
        free(new_priv);
        free(new_pub);
        if(ret != 0)
        {
            goto retry_fail;
        }
        
        klog_log(domain, "bye bye virt fs");
        extern dispatch_queue_t pres_queue(void);
        dispatch_sync(pres_queue(), ^{  /* neutralize the preserver for this tiny moment */
            [[NSFileManager defaultManager] removeItemAtURL:[[NXBootstrap shared] rootfsURL] error:nil];
            [[NSFileManager defaultManager] removeItemAtURL:[[[NXBootstrap shared] rootURL] URLByAppendingPathComponent:@"mntfs"] error:nil];
            
            PERestartSelf();
        });
    }
    os_unfair_lock_unlock(&_lock);
    return YES;
}

- (BOOL)restoreEverything
{
    if(!atomic_load_explicit(&_bootSuccessful, memory_order_acquire))
    {
        return NO;
    }
    
    const char *domain = "PEUserspaceManager:restore";
    
    os_unfair_lock_lock(&_lock);
    goto first;
    
retry_fail: /* a retry shall not happen, happens tho if something goes wrong */
    klog_log(domain, "failed to restore, reattempt restore");
    
first:
    {
        /* needs to be in minimal userspace boot mode to safely begin restoring the container through containerd */
        klog_log(domain, "rebooting userspace into empty mode");
        [self rebootUserspaceWithType_nolock:kPEUserspaceRebootTypeEmpty];
        
        /* now we have to restore the default hostname */
        klog_log(domain, "restoring hostname");
        ksurface_sethostname(@"localhost");
        
        klog_log(domain, "restoring code signature key pair");
        uint8_t *new_priv = NULL, *new_pub = NULL;
        size_t new_priv_len = 0, new_pub_len = 0;
        
        if(!get_kernel_ec_key(&new_priv, &new_priv_len, &new_pub, &new_pub_len))
        {
            goto retry_fail;
        }
        
        int ret = store_kernel_key(new_priv, new_priv_len, new_pub, new_pub_len);
        free(new_priv);
        free(new_pub);
        if(ret != 0)
        {
            goto retry_fail;
        }
        
        klog_log(domain, "bye bye everything");
        /* fuck all defaults */
        [NSUserDefaults.standardUserDefaults removePersistentDomainForName:NSBundle.mainBundle.bundleIdentifier];
        
        extern dispatch_queue_t pres_queue(void);
        dispatch_sync(pres_queue(), ^{  /* neutralize the preserver for this tiny moment */
            /* fuck every thing */
            [[NSFileManager defaultManager] removeItemAtURL:[[NXBootstrap shared] rootURL] error:nil];
            
            PERestartSelf();
        });
    }
    os_unfair_lock_unlock(&_lock);
    return YES;
}

- (BOOL)reloadDaemons_nolock
{
    if(!atomic_load_explicit(&_bootSuccessful, memory_order_acquire))
    {
        return NO;
    }
    
    atomic_store_explicit(&_launchServiceManagerStable, false, memory_order_release);
    [[PELaunchServiceManager shared] invalidateAllEntries];
    if(_mode == kPEUserspaceModeDefault)
    {
        [[PELaunchServiceManager shared] reloadAllEntries];
    }
    else if(_mode == kPEUserspaceModeMinimal)
    {
        [[PELaunchServiceManager shared] loadEntryWithFileName:@"org.emexlabs.containerd.plist"];
    }
    else
    {
        return NO;
    }
    atomic_store_explicit(&_launchServiceManagerStable, true, memory_order_release);
    
    return YES;
}

- (BOOL)reloadDaemons
{
    os_unfair_lock_lock(&_lock);
    BOOL success = [self reloadDaemons_nolock];
    os_unfair_lock_unlock(&_lock);
    return success;
}

- (BOOL)clearApplicationCaches
{
    if(!atomic_load_explicit(&_bootSuccessful, memory_order_acquire))
    {
        return NO;
    }
    
    const char *domain = "PEUserspaceManager:clearApplicationCaches";
    
    os_unfair_lock_lock(&_lock);
    klog_log(domain, "rebooting to default (without apps)");
    [self rebootUserspaceWithType_nolock:kPEUserspaceRebootTypeEmpty];
    
    /* getting containers */
    NSError *error;
    NSURL *root = [[NXBootstrap shared] rootfsURL];
    NSArray<NSString*> *containers = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:[[root URLByAppendingPathComponent:@"/Data/Application"] path] error:&error];
    if(containers == NULL)
    {
        klog_log(domain, "failed to get all applications containers: \"%@\"", error);
        os_unfair_lock_unlock(&_lock);
        return NO;
    }
    
    /* now we gotta clear all caches */
    for(NSString *containerPath in containers)
    {
        NSURL *cachesURL = [root URLByAppendingPathComponent:[@"/Data/Application" stringByAppendingPathComponent:[containerPath stringByAppendingPathComponent:@"/Library/Caches"]]];
        [[NSFileManager defaultManager] removeItemAtURL:cachesURL error:nil];
    }
    
    klog_log(domain, "rebooting back to normal (without apps)");
    [self rebootUserspaceWithType_nolock:kPEUserspaceRebootTypeDefault];
    
    /* userspace in usable state anyways */
    os_unfair_lock_unlock(&_lock);
    return YES;
}

@end
