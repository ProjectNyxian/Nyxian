/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 cr4zyengineer

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

#import <LindChain/ProcEnvironment/Process/PEProcess.h>
#import <LindChain/ProcEnvironment/Process/PEProcessManager.h>
#import <LindChain/WindowServer/NXWindowServer.h>
#import <LindChain/WindowServer/Session/NXWindowSessionApplication.h>
#import <LindChain/ProcEnvironment/Utils/klog.h>

#if !JAILBREAK_ENV
#import <LindChain/Services/applicationmgmtd/LDEApplicationWorkspace.h>
#import <LindChain/Services/containerd/PEContainer.h>
#import <LindChain/ProcEnvironment/Process/PEExtension.h>
#import <LindChain/ProcEnvironment/Syscall/mach_syscall_client.h>
#import <LindChain/ProcEnvironment/Object/PEMachPort.h>
#import <LindChain/ProcEnvironment/Server/Server.h>
#import <LindChain/ProcEnvironment/Surface/proc/counter.h>
#else
#import <LindChain/JBSupport/Shell.h>
#endif /* !JAILBREAK_ENV */

@implementation PEProcess {
    dispatch_once_t _notifyWindowManagerOnce;
}

@dynamic pid;

#if !JAILBREAK_ENV

- (instancetype)initWithItems:(NSDictionary*)items withKernelSurfaceProcess:(ksurface_proc_t*)proc withSession:(NXWindowSessionApplication*)session
{
    if(!proc_count())
    {
        return nil;
    }
    
    self = [super init];
    
    self.session = session;
    
    self.executablePath = items[@"PEExecutablePath"];
    if(self.executablePath == nil) return nil;
    /* FIXME: before it was a isExecutableFileAtPath check, but since installd broke the permissions at install time we can forget that lol */
    if(![[PEContainer shared] isReadableFileAtPath:self.executablePath]) return nil;
    
    self.wid = (id_t)-1;
    
    LDEApplicationObject *applicationObject = [[LDEApplicationWorkspace shared] applicationObjectForExecutablePath:self.executablePath];
    
    self.bundleIdentifier = applicationObject ? applicationObject.bundleIdentifier : nil;
    self.displayName = applicationObject ? applicationObject.localizedName : [self.executablePath lastPathComponent];
    
    __weak typeof(self) weakSelf = self;
    
    /* spawning process */
    self.process = PESpawnFBProcess(items);
    if(self.process == nil)
    {
        return nil;
    }
    
    [self.process addObserver:self];
    if(!self.process.running)
    {
        FBProcessManager *manager = [PrivClass(FBProcessManager) sharedInstance];
        [manager _removeProcess:self.process];
        return nil;
    }
    
    ksurface_proc_t *child = proc_fork(proc, self.pid, [self.executablePath UTF8String]);
    if(child == NULL)
    {
        [self terminate];
        return nil;
    }
    else
    {
        self.proc = child;
    }
    
    NSString *sceneID = [NSString stringWithFormat:@"sceneID:%@-%@", @"LiveProcess", self.process.identifier];
    
    FBSMutableSceneDefinition *definition = [PrivClass(FBSMutableSceneDefinition) definition];
    definition.identity = [PrivClass(FBSSceneIdentity) identityForIdentifier:sceneID];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        __strong typeof(weakSelf) innerSelf = weakSelf;
        if(innerSelf == nil) return;
        
        @try {
            if(!innerSelf.process.rbsHandle || !innerSelf.process.identity)
            {
                @throw [NSException exceptionWithName:@"InvalidProcessIdentity" reason:@"Process handle or identity is nil" userInfo:nil];
            }
            definition.clientIdentity = [PrivClass(FBSSceneClientIdentity) identityForProcessIdentity:innerSelf.process.identity];
        } @catch (NSException *exception) {
            klog_log("LDEProcess", "failed to create client identity for pid %d: %s", innerSelf.pid, [exception.reason UTF8String]);
            [innerSelf terminate];
            return;
        }
        
        definition.specification = [UIApplicationSceneSpecification specification];
        FBSMutableSceneParameters *parameters = [PrivClass(FBSMutableSceneParameters) parametersForSpecification:definition.specification];
        
        UIMutableApplicationSceneSettings *settings = [UIMutableApplicationSceneSettings new];
        settings.canShowAlerts = YES;
        settings.cornerRadiusConfiguration = [[PrivClass(BSCornerRadiusConfiguration) alloc] initWithTopLeft:0 bottomLeft:0 bottomRight:0 topRight:0];
        settings.displayConfiguration = UIScreen.mainScreen.displayConfiguration;
        settings.foreground = NO;
        
        settings.deviceOrientation = UIDevice.currentDevice.orientation;
        settings.interfaceOrientation = UIApplication.sharedApplication.statusBarOrientation;
        
        settings.frame = (innerSelf.session == nil) ? CGRectMake(50, 94, 300, 400) : innerSelf.session.windowRect;
        
        //settings.interruptionPolicy = 2; // reconnect
        settings.level = 1;
        settings.persistenceIdentifier = NSUUID.UUID.UUIDString;
        
        // it seems some apps don't honor these settings so we don't cover the top of the app
        settings.peripheryInsets = UIEdgeInsetsZero;
        settings.safeAreaInsetsPortrait = UIEdgeInsetsZero;
        
        settings.statusBarDisabled = YES;
        parameters.settings = settings;
        
        UIMutableApplicationSceneClientSettings *clientSettings = [UIMutableApplicationSceneClientSettings new];
        clientSettings.interfaceOrientation = UIInterfaceOrientationPortrait;
        clientSettings.statusBarStyle = 0;
        parameters.clientSettings = clientSettings;
        
        innerSelf.scene = [[PrivClass(FBSceneManager) sharedInstance] createSceneWithDefinition:definition initialParameters:parameters];
        innerSelf.scene.delegate = innerSelf;
    });
    
    return self;
}

#endif /* !JAILBREAK_ENV */

- (void)sendSignal:(int)signal
{
#if !JAILBREAK_ENV
    /*
     * those signals are not supported at all
     * (for now atleast).
     */
    if(signal == SIGTTIN ||
       signal == SIGTTOU)
    {
        return;
    }
    
    /*
     * for some reason apple doesnt support SIGTSTP on iOS
     * (maybe we just use it wrong lol)
     */
    if(signal == SIGTSTP)
    {
        signal = SIGSTOP;
    }
    
    if(signal == SIGSTOP)
    {
        _isSuspended = YES;
    }
    else if(signal == SIGCONT)
    {
        _isSuspended = NO;
    }
    
    [self.process.nsExtension _kill:signal];
    
    if(signal == SIGSTOP)
    {
        kvo_wrlock(_proc);
        _proc->bsd.kp_proc.p_stat = SSTOP;
        
        goto report_signal;
    }
    else if(signal == SIGCONT)
    {
        kvo_wrlock(_proc);
        _proc->bsd.kp_proc.p_stat = SRUN;
        
    report_signal:
        kvo_unlock(_proc);
        proc_state_change(_proc, W_STOPCODE(signal));
    }
#else
    kill(self.pid, signal);
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
            if(self.session == nil)
            {
                __block NXWindowSessionApplication *session = [[NXWindowSessionApplication alloc] initWithProcess:self];
                [[NXWindowServer shared] openWindowWithSession:session withCompletion:^(BOOL windowOpened){
                    if(windowOpened)
                    {
                        self.wid = session.windowIdentifier;
                    }
                }];
            }
            else
            {
                if([self.session injectProcess:self])
                {
                    self.wid = self.session.windowIdentifier;
                    [self.session activateWindow];
                }
            }
        });
    });
}
        
- (void)processDidExit:(FBProcess *)arg1
{
#if !JAILBREAK_ENV
    if(self.proc != NULL)
    {
        /* yep writing official wait4 code~~ */
        proc_state_change(self.proc, arg1.exitContext.underlyingContext.legacyCode);
        ksurface_return_t error = proc_zombify(self.proc);
        if(error != SURFACE_SUCCESS)
        {
            klog_log("LDEProcess", "failed to remove pid %d", self.pid);
        }
    }
#endif /* !JAILBREAK_ENV */
    
    if(self.exitingCallback) self.exitingCallback();
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if(self.wid != -1)
        {
            [[NXWindowServer shared] closeWindowWithIdentifier:self.wid withCompletion:nil];
        }
        else if(self.session && self.session.windowIdentifier != -1)
        {
            [[NXWindowServer shared] closeWindowWithIdentifier:self.session.windowIdentifier withCompletion:nil];
        }
        
        if(self.scene != nil)
        {
            [[PrivClass(FBSceneManager) sharedInstance] destroyScene:self.scene withTransitionContext:nil];
            self.scene.delegate = nil;
        }
    });
    
    [[PEProcessManager shared] unregisterProcessWithProcessIdentifier:self.pid];
}

- (void)processWillExit:(FBProcess *)arg1
{
    /* stub for when ever */
}

- (void)process:(FBProcess *)arg1 stateDidChangeFromState:(FBProcessState *)arg2 toState:(FBProcessState *)arg3
{
    /* stub for when ever */
}

- (void)processManager:(FBProcessManager *)arg1 didAddProcess:(FBProcess *)arg2
{
    [arg2 addObserver:self];
}

- (void)processManager:(FBProcessManager *)arg1 didRemoveProcess:(FBProcess *)arg2
{
    [arg2 removeObserver:self];
    [arg1 removeObserver:self];
}

- (id)forwardingTargetForSelector:(SEL)sel
{
    /* redirecting for pid */
    if([self.process respondsToSelector:sel])
    {
        return self.process;
    }
    return [super forwardingTargetForSelector:sel];
}

#if !JAILBREAK_ENV

- (void)dealloc
{
    if(_proc != NULL)
    {
        kvo_release(_proc);
    }
    proc_uncount();
}

#endif /* !JAILBREAK_ENV */

@end
