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
#import <LindChain/Services/applicationmgmtd/LDEApplicationWorkspace.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/panic.h>
#import <Nyxian-Swift.h>
#import <LindChain/ProcEnvironment/Utils/klog.h>

@implementation LDEProcessManager {
    NSTimeInterval _lastSpawnTime;
    NSTimeInterval _spawnCooldown;
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
   withParentProcessIdentifier:(pid_t)parentProcessIdentifier
{
    [self enforceSpawnCooldown];
    
    LDEProcess *process = [[LDEProcess alloc] initWithItems:items withParentProcessIdentifier:parentProcessIdentifier];
    if(!process) return 0;
    pid_t pid = process.pid;
    [self.processes setObject:process forKey:@(pid)];
    return pid;
}

- (pid_t)spawnProcessWithBundleIdentifier:(NSString *)bundleIdentifier
              withParentProcessIdentifier:(pid_t)parentProcessIdentifier
                       doRestartIfRunning:(BOOL)doRestartIfRunning
{
    __block pid_t retval = 0;
    dispatch_sync(_syncQueue, ^{
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
                    retval = process.pid;
                    return;
                }
            }
        }
        
        LDEApplicationObject *applicationObject = [LDEApplicationWorkspace applicationObjectForBundleID:bundleIdentifier];
        if(!applicationObject.isLaunchAllowed)
        {
            [NotificationServer NotifyUserWithLevel:NotifLevelError notification:[NSString stringWithFormat:@"\"%@\" Is No Longer Available", applicationObject.displayName] delay:0.0];
            retval = 0;
            return;
        }
        
        [self enforceSpawnCooldown];
        
        LDEProcess *process = nil;
        retval = [self spawnProcessWithPath:applicationObject.executablePath withArguments:@[applicationObject.executablePath] withEnvironmentVariables:@{
            @"HOME": applicationObject.containerPath
        } withMapObject:nil withParentProcessIdentifier:parentProcessIdentifier process:&process];
    });
    return retval;
}

- (pid_t)spawnProcessWithPath:(NSString*)binaryPath
                withArguments:(NSArray *)arguments
     withEnvironmentVariables:(NSDictionary*)environment
                withMapObject:(FDMapObject*)mapObject
  withParentProcessIdentifier:(pid_t)parentProcessIdentifier
                      process:(LDEProcess**)processReply
{
    [self enforceSpawnCooldown];
    LDEProcess *process = [[LDEProcess alloc] initWithPath:binaryPath withArguments:arguments withEnvironmentVariables:environment withMapObject:mapObject withParentProcessIdentifier:parentProcessIdentifier];
    if(!process) return 0;
    pid_t pid = process.pid;
    [self.processes setObject:process forKey:@(pid)];
    if(processReply) *processReply = process;
    return pid;
}

- (LDEProcess*)processForProcessIdentifier:(pid_t)pid
{
    return [self.processes objectForKey:@(pid)];
}

- (void)unregisterProcessWithProcessIdentifier:(pid_t)pid
{
    dispatch_sync(_syncQueue, ^{
        klog_log(@"LDEProcessManager:unregisterProcessWithProcessIdentifier", @"unregistering pid %d", pid);
        [self.processes removeObjectForKey:@(pid)];
        ksurface_error_t error = proc_exit_for_pid(pid);
        if(error != kSurfaceErrorSuccess)
        {
            klog_log(@"LDEProcessManager:unregisterProcessWithProcessIdentifier", @"failed to exit with pid %d", pid);
        }
    });
}

- (void)closeIfRunningUsingBundleIdentifier:(NSString*)bundleIdentifier
{
    for(NSNumber *key in self.processes)
    {
        LDEProcess *process = self.processes[key];
        if(!process || ![process.bundleIdentifier isEqualToString:bundleIdentifier]) continue;
        else
        {
            [process terminate];
        }
    }
}

@end
