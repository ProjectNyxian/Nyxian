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
    // Does the process requesting even have the entitlement
    if(!proc_got_entitlement(_processIdentifier, PEEntitlementTaskForPid))
    {
        reply(nil);
        return;
    }
    
    // Special or host
    bool prvt = proc_got_entitlement(_processIdentifier, PEEntitlementTaskForPidPrvt);
    bool hostPriveleged = proc_got_entitlement(_processIdentifier, PEEntitlementGetHostTaskPort);
    bool isHost = (pid == getpid());
    
    // Is the request pid the host app
    if(isHost && !hostPriveleged)
    {
        reply(nil);
        return;
    }
    
    // Needs special?
    if(!isHost && !permitive_over_process_allowed(_processIdentifier, pid) && !prvt)
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
- (void)proc_listallpidsViaReply:(void (^)(NSSet*))reply
{
    reply([NSSet setWithArray:[[LDEProcessManager shared] processes].allKeys]);
}

- (void)proc_getProcStructureForProcessIdentifier:(pid_t)pid withReply:(void (^)(LDEProcess*))reply
{
    reply([[LDEProcessManager shared] processForProcessIdentifier:pid]);
}

- (void)proc_kill:(pid_t)pid withSignal:(int)signal withReply:(void (^)(int))reply
{
    // Check
    bool send_signal = proc_got_entitlement(_processIdentifier, PEEntitlementSendSignal);
    bool recv_signal = proc_got_entitlement(_processIdentifier, PEEntitlementRecvSignal);
    bool send_signal_prvt = proc_got_entitlement(_processIdentifier, PEEntitlementSendSignalPrvt);
    
    // Check if process is priveleged enough to send signals
    if(!send_signal)
    {
        reply(1);
        return;
    }
    
    // Check if process is priveleged enough to receive signals
    if(!recv_signal && !send_signal_prvt)
    {
        reply(1);
        return;
    }
    
    // Check if process is permited essentially
    if(!send_signal_prvt && !permitive_over_process_allowed(_processIdentifier, pid))
    {
        reply(1);
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
        // To be done
        didInvokeWindow = [[LDEMultitaskManager shared] openWindowForProcessIdentifier:_processIdentifier];
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
       && proc_got_entitlement(_processIdentifier, PEEntitlementSpawnProc))
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
        reply(proc_surface_handoff());
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
- (void)setCredentialWithOption:(CredentialSet)option withIdentifier:(uid_t)uid withReply:(void (^)(int result))reply
{
    // Check if option is valid
    if(option < 0 ||
       option >= CredentialSetMAX)
    {
        reply(-1);
        return;
    }
    
    BOOL isAlteringAllowed = YES;
    
    // Check for setuid entitlement if applicable
    if ((option == CredentialSetUID ||
         option == CredentialSetEUID ||
         option == CredentialSetRUID) &&
        !proc_got_entitlement(_processIdentifier, PEEntitlementSetUidAllowed))
    {
        isAlteringAllowed = NO;
    }
    
    // Check for setgid entitlement if applicable
    if ((option == CredentialSetGID ||
         option == CredentialSetEGID ||
         option == CredentialSetRGID) &&
        !proc_got_entitlement(_processIdentifier, PEEntitlementSetGidAllowed))
    {
        isAlteringAllowed = NO;
    }
    
    // Now change uid
    kinfo_info_surface_t object = proc_object_for_pid(_processIdentifier);
    
    int repl = 0;
    
    switch(option)
    {
        case CredentialSetUID:
            if(object.real.kp_eproc.e_ucred.cr_uid != uid &&
               object.real.kp_eproc.e_pcred.p_ruid != uid &&
               object.real.kp_eproc.e_pcred.p_svuid != uid)
            {
                if(isAlteringAllowed)
                {
                    object.real.kp_eproc.e_ucred.cr_uid = uid;
                    object.real.kp_eproc.e_pcred.p_ruid = uid;
                    object.real.kp_eproc.e_pcred.p_svuid = uid;
                }
                else
                {
                    repl = -1;
                }
            }
            break;
        case CredentialSetRUID:
            if(object.real.kp_eproc.e_pcred.p_ruid != uid)
            {
                if(isAlteringAllowed)
                {
                    object.real.kp_eproc.e_pcred.p_ruid = uid;
                }
                else
                {
                    repl = -1;
                }
            }
            break;
        case CredentialSetEUID:
            if(object.real.kp_eproc.e_ucred.cr_uid != uid)
            {
                if(isAlteringAllowed)
                {
                    object.real.kp_eproc.e_ucred.cr_uid = uid;
                }
                else
                {
                    repl = -1;
                }
            }
            break;
        case CredentialSetGID:
            if(object.real.kp_eproc.e_ucred.cr_groups[0] != uid &&
               object.real.kp_eproc.e_pcred.p_rgid != uid &&
               object.real.kp_eproc.e_pcred.p_svgid != uid)
            {
                if(isAlteringAllowed)
                {
                    object.real.kp_eproc.e_ucred.cr_groups[0] = uid;
                    object.real.kp_eproc.e_pcred.p_rgid = uid;
                    object.real.kp_eproc.e_pcred.p_svgid = uid;
                }
                else
                {
                    repl = -1;
                }
            }
            break;
        case CredentialSetEGID:
            if(object.real.kp_eproc.e_ucred.cr_groups[0] != uid)
            {
                if(isAlteringAllowed)
                {
                    object.real.kp_eproc.e_ucred.cr_groups[0] = uid;
                }
                else
                {
                    repl = -1;
                }
            }
            break;
        case CredentialSetRGID:
            if(object.real.kp_eproc.e_pcred.p_rgid != uid)
            {
                if(isAlteringAllowed)
                {
                    object.real.kp_eproc.e_pcred.p_rgid = uid;
                }
                else
                {
                    repl = -1;
                }
            }
            break;
        default:
            repl = -1;
    }
    
    proc_object_insert(object);
    
    reply(repl);
    return;
}

/*
 Signer
 */
- (void)signMachO:(MachOObject *)object withReply:(void (^)(void))reply
{
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
    [[LDEMultitaskManager shared] setSnapshotForProcessIdentifier:_processIdentifier withImage:image];
}

@end
