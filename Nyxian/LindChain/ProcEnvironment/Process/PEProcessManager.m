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

#import <LindChain/ProcEnvironment/Process/PEProcessManager.h>

#if !JAILBREAK_ENV
#import <LindChain/Services/applicationmgmtd/LDEApplicationWorkspace.h>
#endif /* !JAILBREAK_ENV */

#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/panic.h>
#import <Nyxian-Swift.h>
#import <LindChain/ProcEnvironment/Utils/klog.h>
#import <os/lock.h>
#import <LindChain/WindowServer/Session/NXWindowSessionApplication.h>
#import <LindChain/ProcEnvironment/Server/Server.h>

@implementation PEProcessManager {
    NSTimeInterval _lastSpawnTime;
    NSTimeInterval _spawnCooldown;
    os_unfair_lock processes_array_lock;
}

- (instancetype)init
{
    self = [super init];
    self.processes = [[NSMutableDictionary alloc] init];
    
    mach_timebase_info_data_t timebase;
    mach_timebase_info(&timebase);
    _spawnCooldown = (100ull * timebase.denom) / timebase.numer;
    _lastSpawnTime = 0;
    _syncQueue = dispatch_queue_create("com.ldeprocessmanager.sync", DISPATCH_QUEUE_SERIAL);
    
    return self;
}

+ (instancetype)shared
{
    static PEProcessManager *processManagerSingletone = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        processManagerSingletone = [[PEProcessManager alloc] init];
    });
    return processManagerSingletone;
}

#if !JAILBREAK_ENV

- (void)enforceSpawnCooldown
{
    uint64_t now = mach_absolute_time();
    uint64_t elapsed = now - _lastSpawnTime;

    if(elapsed < _spawnCooldown)
    {
        uint64_t waitTicks = _spawnCooldown - elapsed;
        
        mach_timebase_info_data_t timebase;
        mach_timebase_info(&timebase);
        uint64_t nsToWait = waitTicks * timebase.numer / timebase.denom;

        struct timespec ts;
        ts.tv_sec = (time_t)(nsToWait / 1000000000ull);
        ts.tv_nsec = (long)(nsToWait % 1000000000ull);
        nanosleep(&ts, NULL);
    }

    _lastSpawnTime = mach_absolute_time();
}

- (pid_t)spawnProcessWithItems:(NSDictionary*)items
      withKernelSurfaceProcess:(ksurface_proc_t*)proc
{
    /* enforcing spawn cooldown */
    [self enforceSpawnCooldown];
    
    /* creating a process */
    PEProcess *process = [[PEProcess alloc] initWithItems:items withKernelSurfaceProcess:proc withSession:nil];
    
    /* null pointer check */
    if(process == nil)
    {
        return -1;
    }
    
    /* getting process identifier */
    pid_t pid = process.pid;
    
    if(pid == -1)
    {
        return -1;
    }
    
    /* inserting process */
    os_unfair_lock_lock(&processes_array_lock);
    [self.processes setObject:process forKey:@(pid)];
    os_unfair_lock_unlock(&processes_array_lock);
    
    /* returning pid */
    return pid;
}

- (pid_t)spawnProcessWithBundleIdentifier:(NSString *)bundleIdentifier
                                withItems:(NSDictionary*)items
                 withKernelSurfaceProcess:(ksurface_proc_t*)proc
                       doRestartIfRunning:(BOOL)doRestartIfRunning
{
    if(proc == NULL)
    {
        proc = kernel_proc_;
    }
    
    NXWindowSessionApplication *session = nil;
    PEProcess *existingProcess = nil;
    
    os_unfair_lock_lock(&processes_array_lock);
    
    for(NSNumber *key in self.processes)
    {
        PEProcess *process = self.processes[key];
        if(process && [process.bundleIdentifier isEqualToString:bundleIdentifier])
        {
            existingProcess = process;
            break;
        }
    }
    
    os_unfair_lock_unlock(&processes_array_lock);

    if(existingProcess != nil)
    {
        NXWindowSession *windowSession = [[NXWindowServer shared] windowSessionForIdentifier:existingProcess.wid];
        if(windowSession != nil)
        {
            if(doRestartIfRunning)
            {
                if(UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad)
                {
                    if([windowSession isKindOfClass:[NXWindowSessionApplication class]])
                    {
                        [((NXWindowSessionApplication*) windowSession) prepareForInject];
                        session = (NXWindowSessionApplication*)windowSession;
                    }
                }
                
                [existingProcess terminate];
            }
            else if(windowSession.window != nil)
            {
                [windowSession.window focusWindow];
                return existingProcess.pid;
            }
            else
            {
                [existingProcess terminate];
            }
        }
        else
        {
            [existingProcess terminate];
        }
    }
    
    LDEApplicationObject *applicationObject = [[LDEApplicationWorkspace shared] applicationObjectForBundleID:bundleIdentifier];
    if(!applicationObject.isLaunchAllowed)
    {
        [NotificationServer NotifyUserWithLevel:NotifLevelError notification:[NSString stringWithFormat:@"\"%@\" Is No Longer Available", applicationObject.localizedName] delay:0.0];
        return -1;
    }
    
    /* enforce cooldown */
    [self enforceSpawnCooldown];
    
    /* creating process */
    NSMutableDictionary *mutableItems = [items mutableCopy];
    
    [mutableItems setValuesForKeysWithDictionary:@{
        @"PEExecutablePath": applicationObject.executablePath,
        @"PEArguments": @[
            applicationObject.executablePath
        ],
        @"PEEnvironment": @{
            @"HOME": applicationObject.containerPath,
            @"CFFIXED_USER_HOME": applicationObject.containerPath,
            @"TMPDIR": [applicationObject.containerPath stringByAppendingPathComponent:@"/Tmp"]
        },
        @"PEWorkingDirectory": [applicationObject.containerPath stringByAppendingPathComponent:@"/Documents"]
    }];
    
    PEProcess *process = [[PEProcess alloc] initWithItems:mutableItems withKernelSurfaceProcess:proc withSession:session];
    
    /* null pointer check */
    if(process == nil)
    {
        return -1;
    }
    
    /* getting pid of process */
    pid_t pid = process.pid;
    
    if(pid == -1)
    {
        return -1;
    }
    
    /* setting process */
    os_unfair_lock_lock(&processes_array_lock);
    [self.processes setObject:process forKey:@(pid)];
    os_unfair_lock_unlock(&processes_array_lock);

    return pid;
}

#else

- (pid_t)spawnProcessWithBundleID:(NSString*)bundleID
{
    /* creating a process */
    PEProcess *process = [[PEProcess alloc] initWithBundleIdentifier:bundleID];
    
    /* null pointer check */
    if(process == nil)
    {
        return -1;
    }
    
    /* getting process identifier */
    pid_t pid = process.pid;
    
    os_unfair_lock_lock(&processes_array_lock);
    [self.processes setObject:process forKey:@(pid)];
    os_unfair_lock_unlock(&processes_array_lock);
    
    /* returning pid */
    return pid;
}

#endif /* !JAILBREAK_ENV */

- (PEProcess*)processForProcessIdentifier:(pid_t)pid
{
    return [self.processes objectForKey:@(pid)];
}

#if !JAILBREAK_ENV
- (PEProcess*)processForBundleIdentifier:(NSString*)bundleIdentifier
{
    PEProcess *existingProcess = nil;
    
    os_unfair_lock_lock(&processes_array_lock);
    
    for(NSNumber *key in self.processes)
    {
        PEProcess *process = self.processes[key];
        if(process && [process.bundleIdentifier isEqualToString:bundleIdentifier])
        {
            existingProcess = process;
            break;
        }
    }
    
    os_unfair_lock_unlock(&processes_array_lock);
    
    return existingProcess;
}
#endif /* !JAILBREAK_ENV */

- (void)unregisterProcessWithProcessIdentifier:(pid_t)pid
{
    /* locking */
    os_unfair_lock_lock(&processes_array_lock);
    
    [self.processes removeObjectForKey:@(pid)];
    
    /* unlocking */
    os_unfair_lock_unlock(&processes_array_lock);
}

- (void)closeIfRunningUsingBundleIdentifier:(NSString*)bundleIdentifier
{
    /* locking */
    os_unfair_lock_lock(&processes_array_lock);
    
    for(NSNumber *key in self.processes)
    {
        PEProcess *process = self.processes[key];
        if(!process || ![process.bundleIdentifier isEqualToString:bundleIdentifier]) continue;
        else
        {
            [process terminate];
        }
    }
    
    /* unlocking */
    os_unfair_lock_unlock(&processes_array_lock);
}

@end
