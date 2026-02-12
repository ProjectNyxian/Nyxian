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

#import <mach/mach.h>
#import <LindChain/ProcEnvironment/Server/ServerSession.h>
#import <LindChain/Services/applicationmgmtd/LDEApplicationWorkspace.h>
#import <LindChain/Multitask/WindowServer/LDEWindowServer.h>
#import <LindChain/Debugger/Logger.h>
#import <LindChain/LiveContainer/LCUtils.h>
#import <LindChain/ProcEnvironment/Surface/permit.h>
#import <LindChain/ProcEnvironment/Surface/entitlement.h>
#import <LindChain/LaunchServices/LaunchService.h>
#import <LindChain/Multitask/WindowServer/Session/LDEWindowSessionApplication.h>
#import <LindChain/ProcEnvironment/Utils/klog.h>
#import <LindChain/ProcEnvironment/Surface/proc/list.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>

@implementation ServerSession

- (instancetype)initWithProcessidentifier:(pid_t)pid
{
    self = [super init];
    _processIdentifier = pid;
    return self;
}

/*
 posix_spawn
 */
- (void)spawnProcessWithPath:(NSString*)path
               withArguments:(NSArray*)arguments
    withEnvironmentVariables:(NSDictionary *)environment
               withMapObject:(FDMapObject*)mapObject
                   withReply:(void (^)(int64_t))reply
{
    /* sanity checking proc */
    if(_proc == NULL)
    {
        /* asking kernel for process structure */
        _proc = proc_for_pid(_processIdentifier);
        
        /* sanity check 2 */
        if(_proc == NULL)
        {
            reply(-1);
            return;
        }
    }
    
    klog_log(@"syscall:spawn", @"pid %d requested to spawn process\nPATH: %@\nARGS: %@\nENVP: %@", _processIdentifier, path, arguments, environment);
    
    if(path &&
       arguments &&
       environment &&
       (entitlement_got_entitlement(proc_getentitlements(_proc), PEEntitlementProcessSpawn) ||
        entitlement_got_entitlement(proc_getentitlements(_proc), PEEntitlementProcessSpawnSignedOnly)))
    {
        /* invoking spawn */
        pid_t pid = [[LDEProcessManager shared] spawnProcessWithPath:path withArguments:arguments withEnvironmentVariables:environment withMapObject:mapObject withKernelSurfaceProcess:_proc enableDebugging:NO process:nil];
        
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
 Server
 */
// TODO: Implement reply.. lazy frida!
- (void)setEndpoint:(NSXPCListenerEndpoint*)endpoint forServiceIdentifier:(NSString*)serviceIdentifier
{
    /* sanity checking proc */
    if(_proc == NULL)
    {
        /* asking kernel for process structure */
        _proc = proc_for_pid(_processIdentifier);
        
        /* sanity check 2 */
        if(_proc == NULL)
        {
            return;
        }
    }
    
    /* null pointer check */
    if(endpoint == NULL ||
       serviceIdentifier == NULL)
    {
        return;
    }
    
    /* iterrating through launchservices */
    for(LaunchService *ls in [[LaunchServices shared] launchServices])
    {
        /*
         * this sequence checks if the service identifier passed is matching
         * and if the process is valid and assigned of the launch service we
         * check and if the process identifier its process has matches ours
         */
        if([ls isServiceWithServiceIdentifier:serviceIdentifier] &&
            ls.process != nil &&
            ls.process.pid == proc_getpid(_proc))
        {
            /* telling launchservices to set the endpoint for the passed service identifier */
            [[LaunchServices shared] setEndpoint:endpoint forServiceIdentifier:serviceIdentifier];
            return;
        }
    }
}

- (void)getEndpointOfServiceIdentifier:(NSString*)serviceIdentifier
                             withReply:(void (^)(NSXPCListenerEndpoint *result))reply
{
    /* sanity checking proc */
    if(_proc == NULL)
    {
        /* asking kernel for process structure */
        _proc = proc_for_pid(_processIdentifier);
        
        /* sanity check 2 */
        if(_proc == NULL)
        {
            reply(nil);
            return;
        }
    }
    
    /* null pointer check */
    if(serviceIdentifier == NULL)
    {
        reply(nil);
        return;
    }
    
    /* checking if process got entitlement to obtain the endpoint of a launch service */
    if(entitlement_got_entitlement(proc_getentitlements(_proc), PEEntitlementLaunchServicesGetEndpoint))
    {
        /* it got it so we as the kernel try to obtain the endpoint first our selves */
        NSXPCListenerEndpoint *endpoint = [[LaunchServices shared] getEndpointForServiceIdentifier:serviceIdentifier];
        
        /* replying with the endpoint, no further ecaluation needed, if its nil then its nil */
        reply(endpoint);
    }
    else
    {
        /* process is not entitled so returning nil */
        reply(nil);
    }
}

/*
 App switcher services
 */
- (void)setSnapshot:(UIImage*)image
{
    /* sanity checking proc */
    if(_proc == NULL)
    {
        /* asking kernel for process structure */
        _proc = proc_for_pid(_processIdentifier);
        
        /* sanity check 2 */
        if(_proc == NULL)
        {
            return;
        }
    }
    
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
