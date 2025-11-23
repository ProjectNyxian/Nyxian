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

#import <LindChain/ProcEnvironment/Server/ServerSession.h>
#import <LindChain/ProcEnvironment/tfp.h>
#import <LindChain/Services/applicationmgmtd/LDEApplicationWorkspace.h>
#import <LindChain/Multitask/WindowServer/LDEWindowServer.h>
#import <LindChain/Debugger/Logger.h>
#import <LindChain/LiveContainer/LCUtils.h>
#import <LindChain/ProcEnvironment/Surface/permit.h>
#import <LindChain/ProcEnvironment/Surface/entitlement.h>
#import <LindChain/LaunchServices/LaunchService.h>
#import <mach/mach.h>
#import <LindChain/Multitask/WindowServer/Session/LDEWindowSessionApplication.h>

@implementation ServerSession

/*
 tfp_userspace
 */
- (void)sendPort:(TaskPortObject*)machPort API_AVAILABLE(ios(26.0));
{
    dispatch_once(&_sendPortOnce, ^{
        if(environment_supports_tfp())
        {
            environment_host_take_client_task_port(machPort);
        }
    });
}

- (void)getPort:(pid_t)pid
      withReply:(void (^)(TaskPortObject*))reply API_AVAILABLE(ios(26.0));
{
    if(environment_supports_tfp())
    {
        // Prepare
        bool isHost = pid == getpid();
        
        // Checking if we have necessary entitlements
        if(!proc_got_entitlement(_processIdentifier, PEEntitlementTaskForPid) ||
           (isHost && !proc_got_entitlement(_processIdentifier, PEEntitlementTaskForPidHost)) ||
           (!isHost && (!proc_got_entitlement(pid, PEEntitlementGetTaskAllowed) || !permitive_over_process_allowed(_processIdentifier, pid))))
        {
            reply(nil);
            return;
        }
        
        // Send requested task port
        mach_port_t port;
        kern_return_t kr = environment_task_for_pid(mach_task_self(), pid, &port);
        reply((kr == KERN_SUCCESS) ? [[TaskPortObject alloc] initWithPort:port] : nil);
    }
    else
    {
        reply(nil);
    }
}

/*
 libproc_userspace
 */
- (void)proc_kill:(pid_t)pid
       withSignal:(int)signal
        withReply:(void (^)(int))reply
{
    // Checking if we have necessary entitlements
    if(pid != _processIdentifier && (!proc_got_entitlement(_processIdentifier, PEEntitlementProcessKill) || !permitive_over_process_allowed(_processIdentifier, pid)))
    {
        reply(-1);
        return;
    }

    // Other target, lets look for it!
    LDEProcess *process = [[LDEProcessManager shared] processForProcessIdentifier:pid];
    if(!process)
    {
        reply(1);
        return;
    }
    
    [process sendSignal:signal];
    
    reply(0);
}

/*
 application
 */
- (void)makeWindowVisibleWithReply:(void (^)(int))reply
{
    __block BOOL didInvokeWindow = NO;
    dispatch_once(&_makeWindowVisibleOnce,^{
        dispatch_sync(dispatch_get_main_queue(), ^{
            // To be done
            LDEProcess *process = [[LDEProcessManager shared] processForProcessIdentifier:_processIdentifier];
            if(process)
            {
                LDEWindowSessionApplication *session = [[LDEWindowSessionApplication alloc] initWithProcessIdentifier:_processIdentifier];
                wid_t wid = (wid_t)-1;
                if([[LDEWindowServer shared] openWindowWithSession:session identifier:&wid])
                {
                    didInvokeWindow = YES;
                }
                process.wid = wid;
            }
        });
    });
    
    reply(didInvokeWindow);
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
    if(path
       && arguments
       && environment
       && mapObject
       && (proc_got_entitlement(_processIdentifier, PEEntitlementProcessSpawn) || proc_got_entitlement(_processIdentifier, PEEntitlementProcessSpawnSignedOnly)))
    {
        // TODO: Inherit entitlements across calls, with the power to drop entitlements, but not getting more entitlements
        LDEProcessConfiguration *processConfig = [LDEProcessConfiguration inheriteConfigurationUsingProcessIdentifier:_processIdentifier];
        reply([[LDEProcessManager shared] spawnProcessWithPath:path withArguments:arguments withEnvironmentVariables:environment withMapObject:mapObject withConfiguration:processConfig process:nil]);
        return;
    }
    
    reply(-1);
}

/*
 surface
 */
- (void)handinSurfaceMappingPortObjectViaReply:(void (^)(MappingPortObject *))reply
{
    dispatch_once(&_handoffSurfaceOnce, ^{
        reply(proc_surface_for_pid(_processIdentifier));
        return;
    });
    
    if(_handoffSurfaceOnce != 0) reply(nil);
}

/*
 Background mode fixup
 */
- (void)setAudioBackgroundModeActive:(BOOL)active
{
    LDEProcess *process = [[LDEProcessManager shared] processForProcessIdentifier:_processIdentifier];
    if(process)
    {
        process.audioBackgroundModeUsage = active;
    }
}

/*
 Set credentials
 */
- (void)setProcessInfoWithOption:(ProcessInfo)option
                  withIdentifier:(unsigned int)uid
                       withReply:(void (^)(unsigned int result))reply
{
    reflock_lock(&(surface->reflock));
    
    ksurface_proc_t proc = {};
    ksurface_error_t error = proc_for_pid(_processIdentifier, &proc);
    
    if(error != kSurfaceErrorSuccess)
    {
        reply(-1);
        reflock_unlock(&(surface->reflock));
        return;
    }
    
    ksurface_proc_t proc_unmod = proc;
    
    switch(option)
    {
        case ProcessInfoUID:
            proc_setuid(proc, uid);
            proc_setsvuid(proc, uid);
            /* FALLTHROUGH */
        case ProcessInfoRUID:
            proc_setruid(proc, uid);
            break;
        case ProcessInfoGID:
            proc_setgid(proc, uid);
            proc_setsvgid(proc, uid);
            /* FALLTHROUGH */
        case ProcessInfoRGID:
            proc_setrgid(proc, uid);
            break;
        case ProcessInfoEUID:
            proc_setuid(proc, uid);
            break;
        case ProcessInfoEGID:
            proc_setgid(proc, uid);
            break;
        default:
            reply(-1);
            reflock_unlock(&(surface->reflock));
            return;
    }
    
    bool processAllowedToElevate = entitlement_got_entitlement(proc_getentitlements(proc_unmod), PEEntitlementProcessElevate);
    bool processWasModified = !(proc_getuid(proc) == proc_getuid(proc_unmod) &&
                                proc_getruid(proc) == proc_getruid(proc_unmod) &&
                                proc_getsvuid(proc) == proc_getsvuid(proc_unmod) &&
                                proc_getgid(proc) == proc_getgid(proc_unmod) &&
                                proc_getrgid(proc) == proc_getrgid(proc_unmod) &&
                                proc_getsvgid(proc) == proc_getsvgid(proc_unmod));
    
    if(processWasModified && processAllowedToElevate)
    {
        error = proc_replace(proc);
        reply((error == kSurfaceErrorSuccess) ? 0 : -1);
        reflock_unlock(&(surface->reflock));
        return;
    }
    else if(processWasModified)
    {
        reply(-1);
        reflock_unlock(&(surface->reflock));
        return;
    }
    
    reply(0);
    reflock_unlock(&(surface->reflock));
    
    return;
}

- (void)getProcessInfoWithOption:(ProcessInfo)option
                       withReply:(void (^)(unsigned long result))reply
{
    ksurface_proc_t proc = {};
    ksurface_error_t error = proc_for_pid(_processIdentifier, &proc);
    
    unsigned long retval = -1;
    
    if(error != kSurfaceErrorSuccess)
    {
        reply(retval);
        return;
    }
    
    switch(option)
    {
        case ProcessInfoUID:
        case ProcessInfoEUID:
            retval = proc_getuid(proc);
            break;
        case ProcessInfoGID:
        case ProcessInfoEGID:
            retval = proc_getgid(proc);
            break;
        case ProcessInfoRUID:
            retval = proc_getruid(proc);
            break;
        case ProcessInfoRGID:
            retval = proc_getrgid(proc);
            break;
        case ProcessInfoPID:
            retval = proc_getpid(proc);
            break;
        case ProcessInfoPPID:
            retval = proc_getppid(proc);
            break;
        case ProcessInfoEntitlements:
            retval = proc_getentitlements(proc);
            break;
        default:
            break;
    }
    
    reply(retval);
    return;
}

/*
 Signer
 */
- (void)signMachO:(MachOObject *)object
        withReply:(void (^)(void))reply
{
    if(!proc_got_entitlement(_processIdentifier, PEEntitlementProcessSpawn))
    {
        reply();
        return;
    }
    
    [object signAndWriteBack];
    reply();
}

/*
 Server
 */
- (void)setEndpoint:(NSXPCListenerEndpoint*)endpoint forServiceIdentifier:(NSString*)serviceIdentifier
{
    BOOL passed = NO;
    for(LaunchService *ls in [[LaunchServices shared] launchServices])
    {
        if([ls isServiceWithServiceIdentifier:serviceIdentifier])
        {
            passed = YES;
        }
    }
    if(passed)
    {
        [[LaunchServices shared] setEndpoint:endpoint forServiceIdentifier:serviceIdentifier];
    }
}

- (void)getEndpointOfServiceIdentifier:(NSString*)serviceIdentifier
                             withReply:(void (^)(NSXPCListenerEndpoint *result))reply
{
    if(proc_got_entitlement(_processIdentifier, PEEntitlementLaunchServicesGetEndpoint))
    {
        reply([[LaunchServices shared] getEndpointForServiceIdentifier:serviceIdentifier]);
    }
    else
    {
        reply([[NSXPCListenerEndpoint alloc] init]);
    }
}

/*
 App switcher services
 */
- (void)setSnapshot:(UIImage*)image
{
    LDEProcess *process = [[LDEProcessManager shared] processForProcessIdentifier:_processIdentifier];
    if(process != nil)
    {
        process.snapshot = image;
    }
}

- (void)waitTillAddedTrapWithReply:(void (^)(BOOL wasAdded))reply
{
    if(_waitTrapOnce != 0)
    {
        reply(NO);
        return;
    }
    
    dispatch_once(&_waitTrapOnce, ^{
        const uint64_t start = mach_absolute_time();
        const uint64_t timeoutNs = 1 * NSEC_PER_SEC;
        
        ksurface_proc_t proc = {};
        BOOL matched = NO;
        
        while (mach_absolute_time() - start < timeoutNs)
        {
            ksurface_error_t error = proc_for_pid(_processIdentifier, &proc);
            if(error == kSurfaceErrorSuccess
               && proc.bsd.kp_proc.p_pid == _processIdentifier)
            {
                matched = YES;
                break;
            }
            usleep(50 * 1000);
        }
        
        reply(matched);
    });
}


@end
