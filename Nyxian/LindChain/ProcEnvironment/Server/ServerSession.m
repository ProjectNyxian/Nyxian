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
#import <LindChain/Multitask/LDEMultitaskManager.h>
#import <LindChain/Debugger/Logger.h>
#import <LindChain/LiveContainer/LCUtils.h>
#import <LindChain/ProcEnvironment/Surface/permit.h>
#import <LindChain/ProcEnvironment/Surface/entitlement.h>
#import <LindChain/LaunchServices/LaunchService.h>
#import <mach/mach.h>
#import <LindChain/Multitask/LDEWindowSessionApplication.h>

@implementation ServerSession

/*
 tfp_userspace
 */
- (void)sendPort:(TaskPortObject*)machPort API_AVAILABLE(ios(26.0));
{
    dispatch_once(&_sendPortOnce, ^{
        environment_host_take_client_task_port(machPort);
    });
}

- (void)getPort:(pid_t)pid
      withReply:(void (^)(TaskPortObject*))reply API_AVAILABLE(ios(26.0));
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

/*
 libproc_userspace
 */
- (void)proc_kill:(pid_t)pid withSignal:(int)signal withReply:(void (^)(int))reply
{
    // Checking if we have necessary entitlements
    if(!proc_got_entitlement(_processIdentifier, PEEntitlementProcessKill) || !permitive_over_process_allowed(_processIdentifier, pid))
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
- (void)makeWindowVisibleWithReply:(void (^)(BOOL))reply
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
                if([[LDEMultitaskManager shared] openWindowWithSession:session identifier:&wid])
                {
                    didInvokeWindow = YES;
                }
                process.windowIdentifier = wid;
            }
        });
    });
    
    reply(didInvokeWindow);
}

/*
 posix_spawn
 */
- (void)spawnProcessWithPath:(NSString*)path withArguments:(NSArray*)arguments withEnvironmentVariables:(NSDictionary *)environment withMapObject:(FDMapObject*)mapObject withReply:(void (^)(pid_t))reply
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
 Code signer
 */
- (void)gatherCodeSignerViaReply:(void (^)(NSData*,NSString*))reply
{
    reply(LCUtils.certificateData, LCUtils.certificatePassword);
}

- (void)gatherSignerExtrasViaReply:(void (^)(NSString*))reply
{
    reply([[NSBundle mainBundle] bundlePath]);
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
- (void)setCredentialWithOption:(Credential)option withIdentifier:(uid_t)uid withReply:(void (^)(int result))reply
{
    kinfo_info_surface_t object = proc_object_for_pid(_processIdentifier);
    kinfo_info_surface_t bobject = object;
    
    switch(option)
    {
        case CredentialUID:
            object.real.kp_eproc.e_ucred.cr_uid = uid;
            object.real.kp_eproc.e_pcred.p_svuid = uid;
        case CredentialRUID:
            object.real.kp_eproc.e_pcred.p_ruid = uid;
            break;
        case CredentialGID:
            object.real.kp_eproc.e_ucred.cr_groups[0] = uid;
            object.real.kp_eproc.e_pcred.p_svgid = uid;
        case CredentialRGID:
            object.real.kp_eproc.e_pcred.p_rgid = uid;
            break;
        case CredentialEUID:
            object.real.kp_eproc.e_ucred.cr_uid = uid;
            break;
        case CredentialEGID:
            object.real.kp_eproc.e_ucred.cr_groups[0] = uid;
            break;
        default:
            reply(-1);
            return;
    }
    
    bool processAllowedToElevate = proc_got_entitlement(_processIdentifier, PEEntitlementProcessElevate);
    bool processObjectIsDifferent = !(proc_getuid(object) == proc_getuid(bobject) &&
                                      proc_getruid(object) == proc_getruid(bobject) &&
                                      proc_getsvuid(object) == proc_getsvuid(bobject) &&
                                      proc_getgid(object) == proc_getgid(bobject) &&
                                      proc_getrgid(object) == proc_getrgid(bobject) &&
                                      proc_getsvgid(object) == proc_getsvgid(bobject));
    
    if(processObjectIsDifferent && processAllowedToElevate)
    {
        proc_object_insert(object);
    }
    else if(processObjectIsDifferent)
    {
        reply(-1);
        return;
    }
    
    reply(0);
    return;
}

- (void)getCredentialWithOption:(Credential)option withReply:(void (^)(uid_t result))reply
{
    kinfo_info_surface_t object = proc_object_for_pid(_processIdentifier);
    
    pid_t repl = 0;
    
    switch(option)
    {
        case CredentialUID:
        case CredentialEUID:
            repl = proc_getuid(object);
            break;
        case CredentialRUID:
            repl = proc_getruid(object);
            break;
        case CredentialGID:
        case CredentialEGID:
            repl = proc_getgid(object);
            break;
        case CredentialRGID:
            repl = proc_getrgid(object);
            break;
        default:
            repl = -1;
    }
    
    reply(repl);
    return;
}

- (void)getParentProcessIdentifierWithReply:(void (^)(pid_t result))reply
{
    kinfo_info_surface_t object = proc_object_for_pid(_processIdentifier);
    reply(proc_getppid(object));
    return;
}

/*
 Signer
 */
- (void)signMachO:(MachOObject *)object withReply:(void (^)(void))reply
{
    if(proc_got_entitlement(_processIdentifier, PEEntitlementProcessSpawnSignedOnly) && !proc_got_entitlement(_processIdentifier, PEEntitlementProcessSpawn))
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
    [[LaunchServices shared] setEndpoint:endpoint forServiceIdentifier:serviceIdentifier];
}

- (void)getEndpointOfServiceIdentifier:(NSString*)serviceIdentifier withReply:(void (^)(NSXPCListenerEndpoint *result))reply
{
    reply([[LaunchServices shared] getEndpointForServiceIdentifier:serviceIdentifier]);
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

@end
