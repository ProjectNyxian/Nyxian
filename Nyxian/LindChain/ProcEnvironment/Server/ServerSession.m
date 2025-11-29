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
#import <LindChain/ProcEnvironment/Utils/klog.h>
#import <LindChain/ProcEnvironment/Surface/proc/userapi/copylist.h>

@implementation ServerSession

- (instancetype)initWithProcessidentifier:(pid_t)pid
{
    self = [super init];
    _processIdentifier = pid;
    return self;
}

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
        ksurface_proc_info_thread_register();
        ksurface_proc_t *proc = proc_for_pid(pid);
        if(proc == NULL)
        {
            ksurface_proc_info_thread_unregister();
            reply(nil);
            return;
        }
        
        ksurface_proc_t *targetProc = proc_for_pid(pid);
        if(targetProc == NULL)
        {
            proc_release(proc);
            ksurface_proc_info_thread_unregister();
            reply(nil);
            return;
        }
        
        
        if(!entitlement_got_entitlement(proc_getentitlements(proc), PEEntitlementTaskForPid) ||
           (isHost && !entitlement_got_entitlement(proc_getentitlements(proc), PEEntitlementTaskForPidHost)) ||
           (!isHost && (!entitlement_got_entitlement(proc_getentitlements(targetProc), PEEntitlementGetTaskAllowed) || !permitive_over_process_allowed(_processIdentifier, pid))))
        {
            proc_release(proc);
            ksurface_proc_info_thread_unregister();
            reply(nil);
            return;
        }
        
        // Send requested task port
        mach_port_t port;
        kern_return_t kr = environment_task_for_pid(mach_task_self(), pid, &port);
        proc_release(proc);
        ksurface_proc_info_thread_unregister();
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
    ksurface_proc_info_thread_register();
    klog_log(@"syscall:kill", @"pid %d requested to signal pid %d with %d", _processIdentifier, pid, signal);
    
    // Checking if we have necessary entitlements
    ksurface_proc_t *proc = proc_for_pid(_processIdentifier);
    if(proc == NULL)
    {
        ksurface_proc_info_thread_unregister();
        reply(2);
        return;
    }
    
    if(pid != _processIdentifier && (!entitlement_got_entitlement(_processIdentifier, PEEntitlementProcessKill) || !permitive_over_process_allowed(_processIdentifier, pid)))
    {
        klog_log(@"syscall:kill", @"pid %d not autorized to kill pid %d", _processIdentifier, pid);
        ksurface_proc_info_thread_unregister();
        reply(-1);
        return;
    }
    ksurface_proc_info_thread_unregister();

    // Other target, lets look for it!
    LDEProcess *process = [[LDEProcessManager shared] processForProcessIdentifier:pid];
    if(!process)
    {
        klog_log(@"syscall:kill", @"pid %d not found on high level process manager", pid);
        reply(1);
        return;
    }
    
    [process sendSignal:signal];
    klog_log(@"syscall:kill", @"pid %d signaled pid %d", _processIdentifier, pid);
    
    reply(0);
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
    ksurface_proc_info_thread_register();
    
    ksurface_proc_t *proc = proc_for_pid(_processIdentifier);
    if(proc == NULL)
    {
        reply(-1);
        return;
    }
    
    if(path
       && arguments
       && environment
       && mapObject
       && (entitlement_got_entitlement(proc_getentitlements(proc), PEEntitlementProcessSpawn) ||
           entitlement_got_entitlement(proc_getentitlements(proc), PEEntitlementProcessSpawnSignedOnly)))
    {
        reply([[LDEProcessManager shared] spawnProcessWithPath:path withArguments:arguments withEnvironmentVariables:environment withMapObject:mapObject withParentProcessIdentifier:_processIdentifier process:nil]);
        proc_release(proc);
        ksurface_proc_info_thread_unregister();
        return;
    }
    
    proc_release(proc);
    ksurface_proc_info_thread_register();
    reply(-1);
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
    ksurface_proc_info_thread_register();
    unsigned int retval = (unsigned int)proc_cred_set(_proc, option, uid);
    ksurface_proc_info_thread_unregister();
    reply(retval);
}

- (void)getProcessInfoWithOption:(ProcessInfo)option
                       withReply:(void (^)(unsigned long result))reply
{
    ksurface_proc_info_thread_register();
    unsigned long retval = proc_cred_get(_proc, option);
    ksurface_proc_info_thread_unregister();
    reply(retval);
}

/*
 Signer
 */
- (void)signMachO:(MachOObject *)object
        withReply:(void (^)(void))reply
{
    ksurface_proc_info_thread_register();
    ksurface_proc_t *proc = proc_for_pid(_processIdentifier);
    if(proc == NULL)
    {
        ksurface_proc_info_thread_unregister();
        reply();
        return;
    }
    
    if(!entitlement_got_entitlement(proc_getentitlements(proc), PEEntitlementProcessSpawn))
    {
        proc_release(proc);
        ksurface_proc_info_thread_unregister();
        reply();
        return;
    }
    
    proc_release(proc);
    ksurface_proc_info_thread_unregister();
    
    [object signAndWriteBack];
    reply();
}

/*
 Server
 */
- (void)setEndpoint:(NSXPCListenerEndpoint*)endpoint forServiceIdentifier:(NSString*)serviceIdentifier
{
    for(LaunchService *ls in [[LaunchServices shared] launchServices])
    {
        if([ls isServiceWithServiceIdentifier:serviceIdentifier] && ls.process != nil && ls.process.pid == _processIdentifier)
        {
            [[LaunchServices shared] setEndpoint:endpoint forServiceIdentifier:serviceIdentifier];
            return;
        }
    }
}

- (void)getEndpointOfServiceIdentifier:(NSString*)serviceIdentifier
                             withReply:(void (^)(NSXPCListenerEndpoint *result))reply
{
    ksurface_proc_info_thread_register();
    ksurface_proc_t *proc = proc_for_pid(_processIdentifier);
    
    if(proc == NULL)
    {
        reply(nil);
    }
    else if(entitlement_got_entitlement(proc_getentitlements(proc), PEEntitlementLaunchServicesGetEndpoint))
    {
        reply([[LaunchServices shared] getEndpointForServiceIdentifier:serviceIdentifier]);
    }
    else
    {
        reply(nil);
    }
    
    if(proc != NULL)
    {
        proc_release(proc);
    }
    
    ksurface_proc_info_thread_unregister();
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
    dispatch_once(&_waitTrapOnce, ^{
        const uint64_t start = mach_absolute_time();
        const uint64_t timeoutNs = 1 * NSEC_PER_SEC;
        
        BOOL matched = NO;
        while (mach_absolute_time() - start < timeoutNs)
        {
            _proc = proc_for_pid(_processIdentifier);
            if(_proc != NULL &&
               proc_getpid(_proc) == _processIdentifier)
            {
                matched = YES;
                break;
            }
            usleep(50 * 1000);
        }
        
        reply(matched);
    });
}

- (void)getProcessTableWithReply:(void (^)(NSData *result))reply
{
    proc_snapshot_t *snap;
    ksurface_proc_info_thread_register();
    proc_list_err_t error = proc_snapshot_create(_processIdentifier, &snap);
    if(error != PROC_LIST_OK)
    {
        ksurface_proc_info_thread_unregister();
        reply(nil);
        return;
    }
    ksurface_proc_info_thread_unregister();
    
    size_t len = snap->count * sizeof(kinfo_proc_t);
    kinfo_proc_t *proc = malloc(len);
    memcpy(proc, snap->kp, len);
    NSData *data = [[NSData alloc] initWithBytes:proc length:len];
    reply(data);
    proc_snapshot_free(snap);
    return;
}

@end
