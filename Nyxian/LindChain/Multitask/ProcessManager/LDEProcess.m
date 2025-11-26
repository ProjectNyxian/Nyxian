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
#import <LindChain/ProcEnvironment/Server/Server.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/Services/applicationmgmtd/LDEApplicationWorkspace.h>
#import <LindChain/Services/trustd/LDETrust.h>

extern NSMutableDictionary<NSString*,NSValue*> *runtimeStoredRectValuesByBundleIdentifier;

@implementation LDEProcess

- (instancetype)initWithItems:(NSDictionary*)items withParentProcessIdentifier:(pid_t)parentProcessIdentifier
{
    self = [super init];
    
    if(runtimeStoredRectValuesByBundleIdentifier == nil)
    {
        runtimeStoredRectValuesByBundleIdentifier = [[NSMutableDictionary alloc] init];
    }
    
    self.displayName = @"LiveProcess";
    self.executablePath = items[@"LSExecutablePath"];
    if(self.executablePath == nil) return nil;
    if(![LDETrust executableAllowedToLaunchAtPath:self.executablePath]) return nil;
    
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
    
    __weak typeof(self) weakSelf = self;
    
    dispatch_semaphore_t sema = dispatch_semaphore_create(0);
    [_extension beginExtensionRequestWithInputItems:@[item] completion:^(NSUUID *identifier) {
        if(identifier)
        {
            if(weakSelf == nil) return;
            __typeof(self) strongSelf = weakSelf;
            
            weakSelf.identifier = identifier;
            weakSelf.pid = [weakSelf.extension pidForRequestIdentifier:weakSelf.identifier];
            RBSProcessPredicate* predicate = [PrivClass(RBSProcessPredicate) predicateMatchingIdentifier:@(weakSelf.pid)];
            weakSelf.processMonitor = [PrivClass(RBSProcessMonitor) monitorWithPredicate:predicate updateHandler:^(RBSProcessMonitor *monitor, RBSProcessHandle *handle, RBSProcessStateUpdate *update) {
                // Interestingly, when a process exits, the process monitor says that there is no state, so we can use that as a logic check
                NSArray<RBSProcessState *> *states = [monitor states];
                if([states count] == 0)
                {
                    // Process dead!
                    dispatch_once(&strongSelf->_removeOnce, ^{
                        if(self.wid != -1) [[LDEWindowServer shared] closeWindowWithIdentifier:strongSelf.wid];
                        [[LDEProcessManager shared] unregisterProcessWithProcessIdentifier:strongSelf.pid];
                        if(strongSelf.exitingCallback) strongSelf.exitingCallback();
                    });
                }
                else
                {
                    dispatch_sync(dispatch_get_main_queue(), ^{
                        // Setting process handle directly from process monitor
                        weakSelf.processHandle = handle;
                        FBProcessManager *manager = [PrivClass(FBProcessManager) sharedInstance];
                        // At this point, the process is spawned and we're ready to create a scene to render in our app
                        [manager registerProcessForAuditToken:self.processHandle.auditToken];
                        self.sceneID = [NSString stringWithFormat:@"sceneID:%@-%@", @"LiveProcess", NSUUID.UUID.UUIDString];
                        
                        FBSMutableSceneDefinition *definition = [PrivClass(FBSMutableSceneDefinition) definition];
                        definition.identity = [PrivClass(FBSSceneIdentity) identityForIdentifier:self.sceneID];
                        
                        // FIXME: Handle when the process is not valid anymore, it will cause EXC_BREAKPOINT otherwise because of "Invalid condition not satisfying: processIdentity"
                        definition.clientIdentity = [PrivClass(FBSSceneClientIdentity) identityForProcessIdentity:self.processHandle.identity];
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
                        if(self.bundleIdentifier != nil)
                        {
                            NSValue *value = runtimeStoredRectValuesByBundleIdentifier[self.bundleIdentifier];
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
                    
                        self.scene = [[PrivClass(FBSceneManager) sharedInstance] createSceneWithDefinition:definition initialParameters:parameters];
                        self.scene.delegate = self;
                    });
                    
                    // TODO: We gonna shrink down this part more and more to move the tasks all slowly to the proc api (ie procv2 eventually)
                    // MARK: The process cannot call UIApplicationMain until its own process was added because of the waittrap it waits in
                    ksurface_error_t error = kSurfaceErrorUndefined;
                    error = proc_new_child_proc(parentProcessIdentifier, weakSelf.pid, weakSelf.executablePath);
                    
                    if(error != kSurfaceErrorSuccess)
                    {
                        [weakSelf terminate];
                    }
                }
            }];
        }
        dispatch_semaphore_signal(sema);
    }];
    dispatch_semaphore_wait(sema, DISPATCH_TIME_FOREVER);
    
    return self;
}

- (instancetype)initWithPath:(NSString*)binaryPath
               withArguments:(NSArray *)arguments
    withEnvironmentVariables:(NSDictionary*)environment
               withMapObject:(FDMapObject*)mapObject
 withParentProcessIdentifier:(pid_t)parentProcessIdentifier
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionaryWithDictionary:@{
        @"LSEndpoint": [Server getTicket],
        @"LSServiceMode": @"spawn",
        @"LSExecutablePath": binaryPath,
        @"LSArguments": arguments,
        @"LSEnvironment": environment
    }];
    
    if(mapObject != nil)
    {
        [dictionary setObject:mapObject forKey:@"LSMapObject"];
    }
    
    self = [self initWithItems:[dictionary copy] withParentProcessIdentifier:parentProcessIdentifier];
    
    return self;
}

/*
 Action
 */
- (void)sendSignal:(int)signal
{
    if(signal == SIGSTOP)
        _isSuspended = YES;
    else if(signal == SIGCONT)
        _isSuspended = NO;
    
    [self.extension _kill:signal];
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

- (void)setRequestCancellationBlock:(void(^)(NSUUID *uuid, NSError *error))callback
{
    [_extension setRequestCancellationBlock:callback];
}

- (void)setRequestInterruptionBlock:(void(^)(NSUUID *uuid))callback
{
    [_extension setRequestInterruptionBlock:callback];
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

@end
