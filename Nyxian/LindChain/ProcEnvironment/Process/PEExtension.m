/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 mach-port-t

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

#import <LindChain/ProcEnvironment/Process/PEExtension.h>
#import <LindChain/ProcEnvironment/Surface/surface.h>
#import <LindChain/ProcEnvironment/Object/PEMachPort.h>
#import <LindChain/ProcEnvironment/Syscall/mach_syscall_server.h>
#import <LindChain/ProcEnvironment/Server/Server.h>
#import <objc/runtime.h>
#import <LindChain/ProcEnvironment/environment.h>
#import <LindChain/ProcEnvironment/Process/PELaunchServiceRegistry.h>

bool liveProcessIsAvailable(void)
{
    static bool available = false;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSBundle *liveProcessBundle = [NSBundle bundleWithPath:[NSBundle.mainBundle.builtInPlugInsPath stringByAppendingPathComponent:@"LiveProcess.appex"]];
        available = (liveProcessBundle != NULL);
    });
    
    return available;
}

static const char kNSExtensionKey;
static const char kIdentifierKey;

@implementation FBProcess (ProcEnvironment)

- (NSString *)nsExtension
{
    return objc_getAssociatedObject(self, &kNSExtensionKey);
}

- (void)setNsExtension:(NSString *)nsExtension
{
    objc_setAssociatedObject(self, &kNSExtensionKey, nsExtension, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (NSString *)identifier
{
    return objc_getAssociatedObject(self, &kIdentifierKey);
}

- (void)setIdentifier:(NSString *)identifier
{
    objc_setAssociatedObject(self, &kIdentifierKey, identifier, OBJC_ASSOCIATION_COPY_NONATOMIC);
}

@end

NSExtension *PEGetNSExtension(void)
{
    static NSBundle *liveProcessBundle = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        liveProcessBundle = [NSBundle bundleWithPath:[NSBundle.mainBundle.builtInPlugInsPath stringByAppendingPathComponent:@"LiveProcess.appex"]];
    });
    
    if(liveProcessBundle == nil)
    {
        return nil;
    }
    
    /* must be one NSExtension per process, idk.. the class is weirdly designed */
    NSError* error = nil;
    NSExtension* extension = [NSExtension extensionWithIdentifier:liveProcessBundle.bundleIdentifier error:&error];
    if(error)
    {
        return nil;
    }
    extension.preferredLanguages = @[];
    return extension;
}

void PESpawnTimeout(void)
{
    static mach_timebase_info_data_t timebase;
    static uint64_t lastSpawnTick = 0;

    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mach_timebase_info(&timebase);
    });

    uint64_t timeoutTicks = (SPAWN_TIMEOUT * timebase.denom) / timebase.numer;

    uint64_t now = mach_absolute_time();
    uint64_t elapsed = now - lastSpawnTick;

    if(lastSpawnTick != 0 && elapsed < timeoutTicks)
    {
        uint64_t waitTicks = timeoutTicks - elapsed;
        uint64_t nsToWait = waitTicks * timebase.numer / timebase.denom;

        struct timespec ts = {
            .tv_sec  = (time_t)(nsToWait / 1000000000ull),
            .tv_nsec = (long)  (nsToWait % 1000000000ull),
        };
        nanosleep(&ts, NULL);
    }

    lastSpawnTick = mach_absolute_time();
}

FBProcess *PESpawnFBProcess(NSDictionary *items)
{
    assert(items != nil);
    
    /* enforce timeout */
    PESpawnTimeout();
    
    NSExtension *extension = PEGetNSExtension();
    
    /* insert required items */
    NSMutableDictionary *mutableItems = [items mutableCopy];
    mutableItems[@"PESyscallPort"] = [PEMachPort portWithPortName:syscall_server_get_port(ksurface->sys_server)];
    mutableItems[@"PEEndpoint"] = [Server getTicket];   /* MARK: deprecated and soon replaced with the syscall server entirely */
    
    NSExtensionItem *item = [NSExtensionItem new];
    item.userInfo = mutableItems;
    
    /*
     * invoke execution (if apple wrote this then
     * it wont hang most likely, apple please handle
     * the case where extension invoke takes too long).
     * isint that the moment in movies where exactly
     * something unexpected like that is the case.. ugh
     */
    NSError *error;
    NSUUID *identifier = [extension beginExtensionRequestWithInputItems:@[item] error:&error];
    
    /* checking if execution it self suceeded */
    if(error != nil || identifier == nil)
    {
        [extension _kill:SIGKILL];
        return false;
    }
    
    pid_t pid = [extension pidForRequestIdentifier:identifier];
    
    /*
     * checking if process is still valid
     * we need its BSD process identifier.
     */
    if(pid < 0)
    {
        [extension _kill:SIGKILL];
        return false;
    }
    
    /* next step is creation of FBProcess */
    RBSProcessPredicate* predicate = [PrivClass(RBSProcessPredicate) predicateMatchingIdentifier:@(pid)];
    RBSProcessHandle *processHandle = [PrivClass(RBSProcessHandle) handleForPredicate:predicate error:&error];
    if(processHandle == nil || error != nil)
    {
        [extension _kill:SIGKILL];
        return nil;
    }
    
    FBProcessManager *manager = [PrivClass(FBProcessManager) sharedInstance];
    FBProcess *process = [manager registerProcessForAuditToken:processHandle.auditToken];
    if(process == nil)
    {
        [extension _kill:SIGKILL];
        return nil;
    }
    
    process.nsExtension = extension;
    process.identifier = identifier;
    
    return process;
}

__attribute__((constructor))
static void start_environment(int argc, char *argv[])
{
#if !JAILBREAK_ENV
    if(liveProcessIsAvailable())
    {
        environment_init(EnvironmentExecCustom, NSBundle.mainBundle.executablePath, argc, argv);
        [PELaunchServiceRegistry shared]; /* invokes launch services startup*/
    }
#else
    if(getsid(getpid()) != getpid())
    {
        return 0;
    }
#endif /* !JAILBREAK_ENV */
}
