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
#import <LindChain/ProcEnvironment/Surface/proc/userapi/copylist.h>
#import <LindChain/ProcEnvironment/tfp.h>
#import <LindChain/ProcEnvironment/tpod.h>
#import <LindChain/ProcEnvironment/Surface/proc/rw.h>

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
                   withReply:(void (^)(unsigned int))reply
{
    /* null pointer check */
    if(_proc == NULL)
    {
        reply(-1);
        return;
    }
    
    klog_log(@"syscall:spawn", @"pid %d requested to spawn process\nPATH: %@\nARGS: %@\nENVP: %@", _processIdentifier, path, arguments, environment);
    
    if(path &&
       arguments &&
       environment &&
       (entitlement_got_entitlement(proc_getentitlements(_proc), PEEntitlementProcessSpawn) ||
        entitlement_got_entitlement(proc_getentitlements(_proc), PEEntitlementProcessSpawnSignedOnly)))
    {
        /* invoking spawn */
        pid_t pid = [[LDEProcessManager shared] spawnProcessWithPath:path withArguments:arguments withEnvironmentVariables:environment withMapObject:mapObject withKernelSurfaceProcess:_proc process:nil];
        
        /* replying with pid of spawn */
        reply(pid);
        
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
        return;
    }
    
    reply(-1);
}

- (void)getProcessNyxWithIdentifier:(pid_t)pid
                          withReply:(void (^)(NSData*))reply
{
    /* null pointer check */
    if(_proc == NULL)
    {
        reply(nil);
        return;
    }
    
    /* attempting to copy process nyx structure */
    knyx_proc_t nyx;
    if(proc_nyx_copy(_proc, pid, &nyx))
    {
        /* replying with copy of nyx */
        reply([[NSData alloc] initWithBytes:&nyx length:sizeof(nyx)]);
        
        /* returning to prevent double reply,
         * which likely caused undefined behaviour before
         */
        return;
    }
    
    /* replying with nothing cause copy failed */
    reply(nil);
}

/*
 Server
 */
// TODO: Implement reply.. lazy frida!
- (void)setEndpoint:(NSXPCListenerEndpoint*)endpoint forServiceIdentifier:(NSString*)serviceIdentifier
{
    /* null pointer check */
    if(_proc == NULL ||
       endpoint == NULL ||
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
    /* null pointer check */
    if(_proc == NULL ||
       serviceIdentifier == NULL)
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
    /* null pointer check */
    if(_proc == NULL ||
       image == NULL)
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

- (void)waitTillAddedTrapWithReply:(void (^)(BOOL wasAdded))reply
{
    /* dispatching once per ServerSession */
    dispatch_once(&_waitTrapOnce, ^{
        /* getting start time */
        const uint64_t start = mach_absolute_time();
        
        /*
         * waittrap timeout is 1 second, this is to prevent ddos.
         * processes are hardwired to go into this waittrap
         * it exists so the ServerSession can safely obtain a
         * reference to the process object of the owner of this
         * server session.
         */
        const uint64_t timeoutNs = 1 * NSEC_PER_SEC;
        
        /* trying to obtain a reference to the process */
        BOOL matched = NO;
        while(mach_absolute_time() - start < timeoutNs)
        {
            /* proc_for_pid(1) references automatically if it finds */
            _proc = proc_for_pid(_processIdentifier);
            
            /* null pointer check */
            if(_proc != NULL)
            {
                /* its not null so it got a reference to the process */
                matched = YES;
                break;
            }
            
            /* to not waste cpu time */
            usleep(50 * 1000);
        }
        
#if KLOG_ENABLED
        if(!matched)
        {
            klog_log(@"syscall:waittrap", @"waittrap for pid %d failed", _processIdentifier);
        }
        else
        {
            klog_log(@"syscall:waittrap", @"waittrap for pid %d succeeded", _processIdentifier);
        }
#endif /* KLOG_ENABLED */
        
        /*
         * replying if matched, and also only once
         * there is only a single time where this waittrap is used
         * its only used to sychronise process creation
         */
        reply(matched);
    });
}

- (void)dealloc
{
    /* null pointer check */
    if(_proc != NULL)
    {
        proc_release(_proc);
    }
}

@end
