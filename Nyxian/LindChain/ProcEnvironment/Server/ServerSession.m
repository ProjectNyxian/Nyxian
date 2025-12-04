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
 tfp_userspace
*/
- (void)sendPort:(TaskPortObject*)machPort API_AVAILABLE(ios(26.0));
{
    /*
     * this is also sensitive, mainly because this is the main bridge
     * how processes handoff their task ports to the kernel process.
     */
    dispatch_once(&_sendPortOnce, ^{
        /*
         * checking if environment supports tfp cuz apple added support
         * for tfp transmittion in iOS 26.0 and removed it again in
         * iOS 26.1, sadly!
         */
        if(environment_supports_tfp())
        {
            /* appending passed tpo to tpod */
            add_tpo(machPort);
        }
    });
}

- (void)getPort:(pid_t)pid
      withReply:(void (^)(TaskPortObject*))reply API_AVAILABLE(ios(26.0));
{
    /*
     * this is one of the most sensitive syscalls in all of nyxian
     * the security checks decide if a process can control nyxian
     * or not!
     */
    
    /*
     * checking if environment supports tfp cuz apple added support
     * for tfp transmittion in iOS 26.0 and removed it again in
     * iOS 26.1, sadly!
     */
    if(environment_supports_tfp())
    {
        /* null pointer check */
        if(_proc == NULL)
        {
            goto reply_nil;
        }
        
        /* checking if the pid passed is the kernel process */
        bool isHost = pid == proc_getpid(kernel_proc_);
        
        /* getting the target process */
        ksurface_proc_t *targetProc = proc_for_pid(pid);
        if(targetProc == NULL)
        {
            goto reply_nil;
        }
        
        /* lock target */
        proc_read_lock(targetProc);
        
        /* get targets entitlements atomically */
        PEEntitlement targetEntitlement = proc_getentitlements(targetProc);
        
        /* were done with the target */
        proc_unlock(targetProc);
        proc_release(targetProc);
        
        /* checking if the caller process got the entitlement to use tfp */
        if(!entitlement_got_entitlement(proc_getentitlements(_proc), PEEntitlementTaskForPid))
        {
            goto reply_nil;
        }
        
        /*
         * it got the entitlement, now we check if the caller process got
         * the permitives to use PEEntitlementTaskForPidHost in case it
         * targets the kernel process. If it doesnt target the kernel process
         * it will check if the target process got PEEntitlementGetTaskAllowed
         * and in that case if the process got necessary permitives to gain
         * permitives over the target process.
         */
        if(isHost)
        {
            if(!entitlement_got_entitlement(proc_getentitlements(_proc), PEEntitlementTaskForPidHost))
            {
                goto reply_nil;
            }
        }
        else
        {
            if(!entitlement_got_entitlement(targetEntitlement, PEEntitlementGetTaskAllowed) || !permitive_over_process_allowed(_proc, pid))
            {
                goto reply_nil;
            }
        }
        
        /* asking tpod for tpo */
        TaskPortObject *tpo = get_tpo_for_pid(pid);
        
        /* null pointer check */
        if(tpo == NULL)
        {
            goto reply_nil;
        }
        
        /* retaining port */
        mach_port_mod_refs(mach_task_self(), [tpo port], MACH_PORT_RIGHT_SEND, 1);
        
        /* giving port caller */
        reply(tpo);
        return;
    }
    
reply_nil:
    reply(nil);
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

/*
 Set credentials
 */
- (void)setProcessCredWithOption:(ProcessCredOp)option
                 withIdentifierA:(unsigned int)ida
                 withIdentifierB:(unsigned int)idb
                 withIdentifierC:(unsigned int)idc
                       withReply:(void (^)(unsigned int result))reply
{
    /* null pointer check */
    if(_proc == NULL)
    {
        reply(-1);
        return;
    }
    
    /* making proc userapi call  */
    unsigned int retval = (unsigned int)proc_cred_set(_proc, option, ida, idb, idc);
    
    /* replying with what ever the userapi replied with */
    reply(retval);
}

- (void)getProcessInfoWithOption:(ProcessInfo)option
                       withReply:(void (^)(unsigned long result))reply
{
    /* null pointer check */
    if(_proc == NULL)
    {
        reply(-1);
        return;
    }
    
    /* making proc userapi call */
    unsigned long retval = proc_cred_get(_proc, option);
    
    /* replying with what ever the userapi replied with */
    reply(retval);
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
 Signer
 */
// TODO: reply with a boolean value.. lazy frida!
- (void)signMachO:(MachOObject *)object
        withReply:(void (^)(void))reply
{
    /* null pointer check */
    if(_proc == NULL ||
       object == NULL)
    {
        reply();
        return;
    }
    
    /*
     * checking process entitlements if spawning is allowed,
     * because it is not PEEntitlementProcessSpawnSignedOnly
     * and PEEntitlementProcessSpawn means that the process
     * is entitlement to dlopen and spawn arbitarily
     */
    if(!entitlement_got_entitlement(proc_getentitlements(_proc), PEEntitlementProcessSpawn))
    {
        reply();
        return;
    }
    
    /* signing and write back */
    [object signAndWriteBack];
    reply();
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
