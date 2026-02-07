/*
 Copyright (C) 2025 cr4zyengineer

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU General Public License for more details.

 You should have received a copy of the GNU General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#import <LindChain/Multitask/ProcessManager/LDEProcessManager.h>

#if !JAILBREAK_ENV
#import <LindChain/Services/applicationmgmtd/LDEApplicationWorkspace.h>
#endif /* !JAILBREAK_ENV */

#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/panic.h>
#import <Nyxian-Swift.h>
#import <LindChain/ProcEnvironment/Utils/klog.h>
#import <os/lock.h>

@implementation LDEProcessManager {
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
    static LDEProcessManager *processManagerSingletone = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        processManagerSingletone = [[LDEProcessManager alloc] init];
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
    LDEProcess *process = [[LDEProcess alloc] initWithItems:items withKernelSurfaceProcess:proc];
    
    /* null pointer check */
    if(process == nil)
    {
        return -1;
    }
    
    /* getting process identifier */
    pid_t pid = process.pid;
    
    /* aquiring lock */
    os_unfair_lock_lock(&processes_array_lock);
    
    /* set process object */
    [self.processes setObject:process forKey:@(pid)];
    
    /* releasing lock */
    os_unfair_lock_unlock(&processes_array_lock);
    
    /* returning pid */
    return pid;
}

- (pid_t)spawnProcessWithBundleIdentifier:(NSString *)bundleIdentifier
                 withKernelSurfaceProcess:(ksurface_proc_t*)proc
                       doRestartIfRunning:(BOOL)doRestartIfRunning
                                  outPipe:(NSPipe*)outp
                                   inPipe:(NSPipe*)inp
                          enableDebugging:(BOOL)enableDebugging
{
    os_unfair_lock_lock(&processes_array_lock);
    for(NSNumber *key in self.processes)
    {
        LDEProcess *process = self.processes[key];
        if(!process || ![process.bundleIdentifier isEqualToString:bundleIdentifier]) continue;
        else
        {
            if(doRestartIfRunning)
            {
                [process terminate];
                if(UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad)
                {
                    // FIXME: If we store two values at the same time then this goes terribly wrong in LDEWindowSessionApplication
                    usleep(300000);
                }
            }
            else
            {
                if(process.wid != (wid_t)-1)
                {
                    if(UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad)
                    {
                        [[LDEWindowServer shared] focusWindowForIdentifier:process.wid];
                    }
                    else
                    {
                        [[LDEWindowServer shared] activateWindowForIdentifier:process.wid animated:YES withCompletion:nil];
                    }
                }
                os_unfair_lock_unlock(&processes_array_lock);
                return process.pid;
            }
        }
    }
    os_unfair_lock_unlock(&processes_array_lock);
    
    LDEApplicationObject *applicationObject = [[LDEApplicationWorkspace shared] applicationObjectForBundleID:bundleIdentifier];
    if(!applicationObject.isLaunchAllowed)
    {
        [NotificationServer NotifyUserWithLevel:NotifLevelError notification:[NSString stringWithFormat:@"\"%@\" Is No Longer Available", applicationObject.displayName] delay:0.0];
        return -1;
    }
    
    [self enforceSpawnCooldown];
    
    FDMapObject *mapObject = nil;
    if(outp != nil && inp != nil)
    {
        mapObject = [FDMapObject emptyMap];
        [mapObject insertOutFD:outp.fileHandleForWriting.fileDescriptor ErrFD:outp.fileHandleForWriting.fileDescriptor InPipe:inp.fileHandleForReading.fileDescriptor];
    }
    
    LDEProcess *process = nil;
    return [self spawnProcessWithPath:applicationObject.executablePath withArguments:@[applicationObject.executablePath] withEnvironmentVariables:@{
        @"HOME": applicationObject.containerPath
    } withMapObject:mapObject withKernelSurfaceProcess:kernel_proc_ enableDebugging:enableDebugging process:&process];
}

- (pid_t)spawnProcessWithBundleIdentifier:(NSString *)bundleIdentifier
                 withKernelSurfaceProcess:(ksurface_proc_t*)proc
                       doRestartIfRunning:(BOOL)doRestartIfRunning
                                  outPipe:(NSPipe*)outp
                                   inPipe:(NSPipe*)inp
{
    return [self spawnProcessWithBundleIdentifier:bundleIdentifier withKernelSurfaceProcess:proc doRestartIfRunning:doRestartIfRunning outPipe:outp inPipe:inp enableDebugging:NO];
}

- (pid_t)spawnProcessWithBundleIdentifier:(NSString *)bundleIdentifier
                 withKernelSurfaceProcess:(ksurface_proc_t*)proc
                       doRestartIfRunning:(BOOL)doRestartIfRunning
{
    return [self spawnProcessWithBundleIdentifier:bundleIdentifier withKernelSurfaceProcess:proc doRestartIfRunning:doRestartIfRunning outPipe:nil inPipe:nil];
}

- (pid_t)spawnProcessWithPath:(NSString*)binaryPath
                withArguments:(NSArray *)arguments
     withEnvironmentVariables:(NSDictionary*)environment
                withMapObject:(FDMapObject*)mapObject
     withKernelSurfaceProcess:(ksurface_proc_t*)proc
              enableDebugging:(BOOL)enableDebugging
                      process:(LDEProcess**)processReply
{
    /* enforce cooldown */
    [self enforceSpawnCooldown];
    
    /* creating process */
    LDEProcess *process = [[LDEProcess alloc] initWithPath:binaryPath withArguments:arguments withEnvironmentVariables:environment withMapObject:mapObject withKernelSurfaceProcess:proc enableDebugging:enableDebugging];
    
    /* null pointer check */
    if(process == nil)
    {
        return 0;
    }
    
    /* getting pid of process */
    pid_t pid = process.pid;
    
    /* aquiring lock */
    os_unfair_lock_lock(&processes_array_lock);
    
    /* setting process */
    [self.processes setObject:process forKey:@(pid)];
    
    /* release lock */
    os_unfair_lock_unlock(&processes_array_lock);
    
    /* checking if its non-null */
    if(processReply != NULL)
    {
        /* replying with the process */
        *processReply = process;
    }
    
    /* returning process identifier */
    return pid;
}

#else

- (pid_t)spawnProcessWithBundleID:(NSString*)bundleID
{
    /* creating a process */
    LDEProcess *process = [[LDEProcess alloc] initWithBundleID:bundleID];
    
    /* null pointer check */
    if(process == nil)
    {
        return -1;
    }
    
    /* getting process identifier */
    pid_t pid = process.pid;
    
    /* aquiring lock */
    os_unfair_lock_lock(&processes_array_lock);
    
    /* set process object */
    [self.processes setObject:process forKey:@(pid)];
    
    /* releasing lock */
    os_unfair_lock_unlock(&processes_array_lock);
    
    /* returning pid */
    return pid;
}

#endif /* !JAILBREAK_ENV */

- (LDEProcess*)processForProcessIdentifier:(pid_t)pid
{
    return [self.processes objectForKey:@(pid)];
}

- (void)unregisterProcessWithProcessIdentifier:(pid_t)pid
{
    /* locking */
    os_unfair_lock_lock(&processes_array_lock);
    
    klog_log(@"LDEProcessManager:unregisterProcessWithProcessIdentifier", @"unregistering pid %d", pid);
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
        LDEProcess *process = self.processes[key];
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
