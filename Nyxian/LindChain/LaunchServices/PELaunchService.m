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

#import <LindChain/LaunchServices/PELaunchService.h>
#import <LindChain/Multitask/ProcessManager/LDEProcessManager.h>

@implementation PELaunchService

+ (instancetype)launchServiceWithPlistPath:(NSString*)plistPath
{
    return [[self alloc] initWithPlistPath:plistPath];
}

- (instancetype)initWithPlistPath:(NSString*)plistPath
{
    self = [super init];
    _lock = OS_UNFAIR_LOCK_INIT;
    _dictionary = [NSDictionary dictionaryWithContentsOfFile:plistPath];
    
    /* TODO: add sanitization */
    _executablePath = _dictionary[@"PEExecutablePath"];
    _serviceIdentifier = _dictionary[@"PEServiceIdentifier"];
    _autoRestart = [((NSNumber*)[_dictionary valueForKey:@"PEShouldAutorestart"]) boolValue];
    
    [self ignition];
    
    return self;
}

- (void)ignition
{
    NSDictionary *dictionary = _dictionary;
    
#if DEBUG
    NSMutableDictionary *mutableDictionary = [_dictionary mutableCopy];
    FDMapObject *mapObject = [FDMapObject emptyMap];
    [mapObject appendFileDescriptor:STDIN_FILENO withMappingToLoc:STDIN_FILENO];
    [mapObject appendFileDescriptor:STDOUT_FILENO withMappingToLoc:STDOUT_FILENO];
    [mapObject appendFileDescriptor:STDERR_FILENO withMappingToLoc:STDERR_FILENO];
    [mutableDictionary setObject:mapObject forKey:@"PEMapObject"];
    dictionary = [mutableDictionary copy];
#endif /* DEBUG */
    
    pid_t pid = [[LDEProcessManager shared] spawnProcessWithItems:dictionary withKernelSurfaceProcess:kernel_proc_];
    if(pid < 0)
    {
        [self ignition];
    }
    
    /* getting lock */
    os_unfair_lock_lock(&_lock);
    _process = [[LDEProcessManager shared] processForProcessIdentifier:pid];
    if(_process == nil)
    {
        os_unfair_lock_unlock(&_lock);
        [self ignition];
    }
    
    /* now assign handlers */
    if(self.shouldAutorestart)
    {
        __weak typeof(self) weakSelf = self;
        [_process setExitingCallback:^{
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                [weakSelf ignition];
            });
        }];
    }
    
    os_unfair_lock_unlock(&_lock);
}

- (BOOL)isServiceWithServiceIdentifier:(NSString*)serviceIdentifier
{
    return [_serviceIdentifier isEqualToString:serviceIdentifier];
}

- (LDEProcess*)getProcess
{
    LDEProcess *process = nil;
    os_unfair_lock_lock(&_lock);
    process = _process;
    os_unfair_lock_unlock(&_lock);
    return process;
}

- (NSString*)getExecutablePath
{
    return _executablePath;
}

- (NSString*)getServiceIdentifier
{
    return _serviceIdentifier;
}

- (BOOL)shouldAutorestart
{
    return _autoRestart;
}

@end
