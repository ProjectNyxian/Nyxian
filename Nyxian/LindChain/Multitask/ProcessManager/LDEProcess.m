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

#import <LindChain/Multitask/ProcessManager/LDEProcessManager.h>
#import <LindChain/Multitask/WindowServer/LDEWindowServer.h>
#import <LindChain/Multitask/WindowServer/Session/LDEWindowSessionApplication.h>
#import <LindChain/ProcEnvironment/Utils/klog.h>

#if !JAILBREAK_ENV
#import <LindChain/ProcEnvironment/Server/Server.h>
#import <LindChain/Services/applicationmgmtd/LDEApplicationWorkspace.h>
#import <LindChain/Services/trustd/LDETrust.h>
#import <LindChain/ProcEnvironment/Syscall/mach_syscall_client.h>
#import <LindChain/ProcEnvironment/Object/MachPortObject.h>
#else
#import <LindChain/JBSupport/Shell.h>
#endif /* !JAILBREAK_ENV */

extern NSMutableDictionary<NSString*,NSValue*> *runtimeStoredRectValuesByBundleIdentifier;

@implementation LDEProcess

#if !JAILBREAK_ENV
- (instancetype)initWithItems:(NSDictionary*)items withKernelSurfaceProcess:(ksurface_proc_t*)proc
#else
- (instancetype)initWithBundleID:(NSString*)bundleID
#endif /* !JAILBREAK_ENV */
{
    self = [super init];
 
#if !JAILBREAK_ENV
    
    NSMutableDictionary *mutableItems = [items mutableCopy];
    mutableItems[@"LSSyscallPort"] = [[MachPortObject alloc] initWithPort:syscall_server_get_port(ksurface->sys_server)];
    items = [mutableItems copy];
    
    if(runtimeStoredRectValuesByBundleIdentifier == nil)
    {
        runtimeStoredRectValuesByBundleIdentifier = [[NSMutableDictionary alloc] init];
    }
    
    self.executablePath = items[@"LSExecutablePath"];
    if(self.executablePath == nil) return nil;
    if(![[LDETrust shared] executableAllowedToLaunchAtPath:self.executablePath]) return nil;
    
    self.wid = (wid_t)-1;
    
    NSBundle *liveProcessBundle = [NSBundle bundleWithPath:[NSBundle.mainBundle.builtInPlugInsPath stringByAppendingPathComponent:@"LiveProcess.appex"]];
    if(!liveProcessBundle) {
        return nil;
    }
    
    NSError* error = nil;
    _extension = [NSExtension extensionWithIdentifier:liveProcessBundle.bundleIdentifier error:&error];
    if(error) {
        return nil;
    }
    _extension.preferredLanguages = @[];
    
    NSExtensionItem *item = [NSExtensionItem new];
    item.userInfo = items;

    LDEApplicationObject *applicationObject = [[LDEApplicationWorkspace shared] applicationObjectForExecutablePath:self.executablePath];
#else
    LSApplicationProxy *applicationObject = nil;
    NSArray<LSApplicationProxy*> *array = LSApplicationWorkspace.defaultWorkspace.allInstalledApplications;
    for(LSApplicationProxy *proxy in array)
    {
        if([proxy.bundleIdentifier isEqualToString:bundleID])
        {
            applicationObject = proxy;
            break;
        }
    }
#endif /* !JAILBREAK_ENV */
    
    
    if(applicationObject != nil)
    {
        self.bundleIdentifier = applicationObject.bundleIdentifier;
        
#if !JAILBREAK_ENV
        self.displayName = applicationObject.displayName;
#else
        self.displayName = applicationObject.localizedName;
#endif
    }
    else
    {
#if !JAILBREAK_ENV
        self.bundleIdentifier = nil;
        self.displayName = [self.executablePath lastPathComponent];
#else
        return nil;
#endif
    }
    
    __weak typeof(self) weakSelf = self;
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    
#if !JAILBREAK_ENV
    
    [_extension beginExtensionRequestWithInputItems:@[item] completion:^(NSUUID *identifier) {
        if(identifier)
        {
            if(weakSelf == nil) return;
            __strong typeof(weakSelf) innerSelf = weakSelf;
            
            weakSelf.identifier = identifier;
            weakSelf.pid = [weakSelf.extension pidForRequestIdentifier:weakSelf.identifier];
            RBSProcessPredicate* predicate = [PrivClass(RBSProcessPredicate) predicateMatchingIdentifier:@(weakSelf.pid)];
            
#else
            
    RBSProcessIdentity* identity = [PrivClass(RBSProcessIdentity) identityForEmbeddedApplicationIdentifier:applicationObject.bundleIdentifier];
    RBSProcessPredicate* predicate = [PrivClass(RBSProcessPredicate) predicateMatchingIdentity:identity];
    FBProcessManager *manager = [PrivClass(FBProcessManager) sharedInstance];
            
    FBApplicationProcessLaunchTransaction *transaction = [[PrivClass(FBApplicationProcessLaunchTransaction) alloc] initWithProcessIdentity:identity executionContextProvider:^id(void){
        FBMutableProcessExecutionContext *context = [PrivClass(FBMutableProcessExecutionContext) new];
        context.identity = identity;
        context.environment = @{};
        context.launchIntent = 4;
        return [manager launchProcessWithContext:context];
    }];
            
    [transaction setCompletionBlock:^{
        if(weakSelf != nil)
        {
            __strong typeof(weakSelf) innerSelf = weakSelf;
        
            self.sceneID = [NSString stringWithFormat:@"sceneID:%@-%@", bundleID, @"default"];
            RBSProcessHandle* processHandle = [PrivClass(RBSProcessHandle) handleForPredicate:predicate error:nil];
            self.pid = processHandle.pid;
            
#endif /* !JAILBREAK_ENV */
            
            innerSelf.processMonitor = [PrivClass(RBSProcessMonitor) monitorWithPredicate:predicate updateHandler:^(RBSProcessMonitor *monitor, RBSProcessHandle *handle, RBSProcessStateUpdate *update) {
                if(weakSelf == nil) return;
                __strong typeof(weakSelf) innerSelf = weakSelf;
                
                // Interestingly, when a process exits, the process monitor says that there is no state, so we can use that as a logic check
                NSArray<RBSProcessState *> *states = [monitor states];
                if([states count] == 0)
                {
                    // Remove Once
                    dispatch_once(&innerSelf->_removeOnce, ^{
                        
#if !JAILBREAK_ENV
                        klog_log(@"LDEProcess", @"pid %d died", innerSelf.pid);
                        ksurface_return_t error = proc_exit(innerSelf.proc);
                        if(error != kSurfaceReturnSuccess && error != kSurfaceReturnProcessDead)
                        {
                            klog_log(@"LDEProcess", @"failed to remove pid %d", innerSelf.pid);
                        }
#endif /* !JAILBREAK_ENV */
                        
                        [innerSelf.processMonitor invalidate];
                        if(innerSelf.exitingCallback) innerSelf.exitingCallback();
                        if(self.wid != -1) [[LDEWindowServer shared] closeWindowWithIdentifier:self.wid];
                        [[LDEProcessManager shared] unregisterProcessWithProcessIdentifier:self.pid];
                    });
                }
                else
                {
                    // Initilize once
                    dispatch_once(&innerSelf->_addOnce, ^{
                        dispatch_sync(dispatch_get_main_queue(), ^{
                            // Setting process handle directly from process monitor
                            weakSelf.processHandle = handle;
                            FBProcessManager *manager = [PrivClass(FBProcessManager) sharedInstance];
                            // At this point, the process is spawned and we're ready to create a scene to render in our app
                            [manager registerProcessForAuditToken:innerSelf.processHandle.auditToken];
                            innerSelf.sceneID = [NSString stringWithFormat:@"sceneID:%@-%@", @"LiveProcess", NSUUID.UUID.UUIDString];
                            
                            FBSMutableSceneDefinition *definition = [PrivClass(FBSMutableSceneDefinition) definition];
                            definition.identity = [PrivClass(FBSSceneIdentity) identityForIdentifier:innerSelf.sceneID];
                            
                            @try {
                                if (!innerSelf.processHandle || !innerSelf.processHandle.identity) {
                                    @throw [NSException exceptionWithName:@"InvalidProcessIdentity"
                                                                   reason:@"Process handle or identity is nil"
                                                                 userInfo:nil];
                                }
                                definition.clientIdentity = [PrivClass(FBSSceneClientIdentity) identityForProcessIdentity:innerSelf.processHandle.identity];
                            } @catch (NSException *exception) {
                                klog_log(@"LDEProcess", @"failed to create client identity for pid %d: %@", weakSelf.pid, exception.reason);
                                [weakSelf terminate];
                                return;
                            }
                            
                            definition.specification = [UIApplicationSceneSpecification specification];
                            FBSMutableSceneParameters *parameters = [PrivClass(FBSMutableSceneParameters) parametersForSpecification:definition.specification];
                            
                            UIMutableApplicationSceneSettings *settings = [UIMutableApplicationSceneSettings new];
                            settings.canShowAlerts = YES;
                            settings.cornerRadiusConfiguration = [[PrivClass(BSCornerRadiusConfiguration) alloc] initWithTopLeft:0 bottomLeft:0 bottomRight:0 topRight:0];
                            settings.displayConfiguration = UIScreen.mainScreen.displayConfiguration;
                            settings.foreground = YES;
                            
                            settings.deviceOrientation = UIDevice.currentDevice.orientation;
                            settings.interfaceOrientation = UIApplication.sharedApplication.statusBarOrientation;
                            
                            CGRect rect = CGRectMake(50, 50, 400, 400);
                            if(innerSelf.bundleIdentifier != nil)
                            {
                                NSValue *value = runtimeStoredRectValuesByBundleIdentifier[innerSelf.bundleIdentifier];
                                if(value != nil)
                                {
                                    rect = [value CGRectValue];
                                }
                            }
                            settings.frame = rect;
                            
                            //settings.interruptionPolicy = 2; // reconnect
                            settings.level = 1;
                            settings.persistenceIdentifier = NSUUID.UUID.UUIDString;
                            
                            // it seems some apps don't honor these settings so we don't cover the top of the app
                            settings.peripheryInsets = UIEdgeInsetsMake(0, 0, 0, 0);
                            settings.safeAreaInsetsPortrait = UIEdgeInsetsMake(0, 0, 0, 0);
                            
                            settings.statusBarDisabled = YES;
                            parameters.settings = settings;
                            
                            UIMutableApplicationSceneClientSettings *clientSettings = [UIMutableApplicationSceneClientSettings new];
                            clientSettings.interfaceOrientation = UIInterfaceOrientationPortrait;
                            clientSettings.statusBarStyle = 0;
                            parameters.clientSettings = clientSettings;
                            
                            innerSelf.scene = [[PrivClass(FBSceneManager) sharedInstance] createSceneWithDefinition:definition initialParameters:parameters];
                            innerSelf.scene.delegate = innerSelf;
                        });
                        
#if !JAILBREAK_ENV
                        // TODO: We gonna shrink down this part more and more to move the tasks all slowly to the proc api (ie procv2 eventually)
                        // MARK: The process cannot call UIApplicationMain until its own process was added because of the waittrap it waits in
                        ksurface_proc_t *child = proc_fork(proc, weakSelf.pid, [weakSelf.executablePath UTF8String]);
                        if(child == NULL)
                        {
                            klog_log(@"LDEProcess", @"failed to create child process with proc api");
                            [weakSelf terminate];
                        }
                        else
                        {
                            weakSelf.proc = child;
                        }
                        klog_log(@"LDEProcess", @"forked process @ %p of process @ %p", child, proc);
#endif /* !JAILBREAK_ENV */
                    });
                }
            }];
        }
        dispatch_semaphore_signal(sema);
    }];
            
#if JAILBREAK_ENV
    dispatch_async(dispatch_get_main_queue(), ^{
        [transaction begin];
    });
#endif /* JAILBREAK_ENV*/

    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    
    return self;
}

#if !JAILBREAK_ENV

- (instancetype)initWithPath:(NSString*)binaryPath
               withArguments:(NSArray *)arguments
    withEnvironmentVariables:(NSDictionary*)environment
               withMapObject:(FDMapObject*)mapObject
    withKernelSurfaceProcess:(ksurface_proc_t *)proc
        enableDebugging:(BOOL)enableDebugging
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithDictionary:@{
        @"LSEndpoint": [Server getTicket],
        @"LSServiceMode": @"spawn",
        @"LSExecutablePath": binaryPath,
        @"LSArguments": arguments,
        @"LSEnvironment": environment,
        @"LDEDebugEnabled": @(enableDebugging)
    }];
    
    if(mapObject != nil)
    {
        [dictionary setObject:mapObject forKey:@"LSMapObject"];
    }
    
    self = [self initWithItems:[dictionary copy] withKernelSurfaceProcess:proc];
    
    return self;
}

#endif /* !JAILBREAK_ENV */

/*
 Action
 */
- (void)sendSignal:(int)signal
{
    if(signal == SIGSTOP)
        _isSuspended = YES;
    else if(signal == SIGCONT)
        _isSuspended = NO;
    
#if !JAILBREAK_ENV
    [self.extension _kill:signal];
#else
    shell([NSString stringWithFormat:@"kill -%d %d", signal, self.pid], 0, nil, nil);
#endif /* !JAILBREAK_ENV */
}

- (BOOL)suspend
{
    if(!_audioBackgroundModeUsage)
    {
        [self sendSignal:SIGSTOP];
        return YES;
    }
    else
    {
        return NO;
    }
}

- (BOOL)resume
{
    [self sendSignal:SIGCONT];
    return YES;
}

- (BOOL)terminate
{
    [self sendSignal:SIGKILL];
    return YES;
}

- (void)setExitingCallback:(void(^)(void))callback
{
    _exitingCallback = callback;
}

- (void)scene:(FBScene *)arg1 didCompleteUpdateWithContext:(FBSceneUpdateContext *)arg2 error:(NSError *)arg3
{
    dispatch_once(&_notifyWindowManagerOnce, ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            LDEWindowSessionApplication *session = [[LDEWindowSessionApplication alloc] initWithProcess:self];
            [[LDEWindowServer shared] openWindowWithSession:session identifier:&(self->_wid)];
        });
    });
}

#if !JAILBREAK_ENV
        
- (void)dealloc
{
    if(_proc != NULL)
    {
        kvo_release(_proc);
    }
    NSLog(@"deallocated %@", self);
}
        
#endif /* !JAILBREAK_ENV */

@end
