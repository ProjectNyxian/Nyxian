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

#import <mach/mach.h>
#import <LindChain/ProcEnvironment/Server/ServerSession.h>
#import <LindChain/Services/applicationmgmtd/LDEApplicationWorkspace.h>
#import <LindChain/Multitask/WindowServer/LDEWindowServer.h>
#import <LindChain/Debugger/Logger.h>
#import <LindChain/LiveContainer/LCUtils.h>
#import <LindChain/ProcEnvironment/Surface/permit.h>
#import <LindChain/ProcEnvironment/Surface/entitlement.h>
#import <LindChain/Multitask/WindowServer/Session/LDEWindowSessionApplication.h>
#import <LindChain/ProcEnvironment/Utils/klog.h>
#import <LindChain/ProcEnvironment/Surface/proc/list.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>

@interface ServerSession ()

@property (nonatomic,getter=proc) ksurface_proc_t *proc;

@end

@implementation ServerSession {
    pid_t _processIdentifier;
}

- (instancetype)initWithProcessidentifier:(pid_t)pid
{
    self = [super init];
    _processIdentifier = pid;
    return self;
}

- (ksurface_proc_t*)proc
{
    if(_proc == NULL)
    {
        /* attempting to get proc from ksurface */
        ksurface_return_t ret = proc_for_pid(_processIdentifier, &(_proc));
        if(ret != SURFACE_SUCCESS)
        {
            return NULL;
        }
    }
    
    return _proc;
}

/*
 posix_spawn
 */
- (void)spawnProcessWithPath:(NSString*)path
               withArguments:(NSArray<NSObject<NSSecureCoding,NSCopying>*>*)arguments
    withEnvironmentVariables:(NSDictionary *)environment
               withMapObject:(FDMapObject*)mapObject
        withWorkingDirectory:(NSString *)workingDirectory
                   withReply:(void (^)(int64_t))reply
{
    /* sanity checking proc */
    if(self.proc == NULL)
    {
        reply(-1);
        return;
    }
    
    if(path &&
       arguments &&
       environment &&
       workingDirectory &&
       (entitlement_got_entitlement(proc_getentitlements(_proc), PEEntitlementProcessSpawn) ||
        entitlement_got_entitlement(proc_getentitlements(_proc), PEEntitlementProcessSpawnSignedOnly)))
    {
        kvo_rdlock(_proc);
        
        if([environment objectForKey:@"DYLD_INSERT_LIBRARIES"] &&
           !entitlement_got_entitlement(proc_getentitlements(_proc), PEEntitlementPlatform) &&
           proc_geteuid(_proc) != 0)
        {
            kvo_unlock(_proc);
            reply(-1);
            return;
        }
        
        kvo_unlock(_proc);
        
        NSMutableDictionary *mutableItems = [[NSMutableDictionary alloc] initWithDictionary:@{
            @"PEExecutablePath": path,
            @"PEArguments": arguments,
            @"PEEnvironment": environment,
            @"PEMapObject": mapObject ? mapObject : [FDMapObject emptyMap],
            @"PEWorkingDirectory": workingDirectory,
        }];
        
        if(mapObject != nil)
        {
            [mutableItems setObject:mapObject forKey:@"PEMapObject"];
        }
        
        /* invoking spawn */
        pid_t pid = [[LDEProcessManager shared] spawnProcessWithItems:mutableItems withKernelSurfaceProcess:_proc];
        
#if KLOG_ENABLED
        if(pid != -1)
        {
            klog_log(@"syscall:spawn", @"pid %d spawned pid %d", _processIdentifier, pid);
        }
        else
        {
            klog_log(@"syscall:spawn", @"pid %d failed to spawn process", _processIdentifier);
        }
#endif /* KLOG_ENABLED */
        
        /* replying with pid of spawn */
        reply(pid);
        
        return;
    }
    
    reply(-1);
}

/*
 App switcher services
 */
- (void)setSnapshot:(UIImage*)image
{
    /* null pointer check */
    if(image == NULL)
    {
        return;
    }
    
    /* finding process */
    LDEProcess *process = [[LDEProcessManager shared] processForProcessIdentifier:_processIdentifier];
    if(process != nil)
    {
        /* setting snapshot */
        process.snapshot = image;
    }
}

- (void)dealloc
{
    /* null pointer check */
    if(_proc != NULL)
    {
        kvo_release(_proc);
    }
}

@end
