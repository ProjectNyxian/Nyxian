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

#import <LindChain/Multitask/LDEWindowSessionApplication.h>
#import <LindChain/ProcEnvironment/Surface/proc.h>

@implementation LDEWindowSessionApplication

@synthesize windowSize;
@synthesize windowName;

- (instancetype)initWithProcessIdentifier:(pid_t)processIdentifier
{
    self = [super init];
    _processIdentifier = processIdentifier;
    _process = [[LDEProcessManager shared] processForProcessIdentifier:_processIdentifier];
    self.windowName = @"Meow";
    return self;
}

- (BOOL)openWindowWithScene:(UIWindowScene*)windowScene
{
    FBProcessManager *manager = [PrivClass(FBProcessManager) sharedInstance];
    // At this point, the process is spawned and we're ready to create a scene to render in our app
    [manager registerProcessForAuditToken:self.process.processHandle.auditToken];
    self.sceneID = [NSString stringWithFormat:@"sceneID:%@-%@", @"LiveProcess", NSUUID.UUID.UUIDString];
    
    FBSMutableSceneDefinition *definition = [PrivClass(FBSMutableSceneDefinition) definition];
    definition.identity = [PrivClass(FBSSceneIdentity) identityForIdentifier:self.sceneID];
    
    // FIXME: Handle when the process is not valid anymore, it will cause EXC_BREAKPOINT otherwise because of "Invalid condition not satisfying: processIdentity"
    definition.clientIdentity = [PrivClass(FBSSceneClientIdentity) identityForProcessIdentity:self.process.processHandle.identity];
    definition.specification = [UIApplicationSceneSpecification specification];
    FBSMutableSceneParameters *parameters = [PrivClass(FBSMutableSceneParameters) parametersForSpecification:definition.specification];
    
    UIMutableApplicationSceneSettings *settings = [UIMutableApplicationSceneSettings new];
    settings.canShowAlerts = YES;
    settings.cornerRadiusConfiguration = [[PrivClass(BSCornerRadiusConfiguration) alloc] initWithTopLeft:self.view.layer.cornerRadius bottomLeft:self.view.layer.cornerRadius bottomRight:self.view.layer.cornerRadius topRight:self.view.layer.cornerRadius];
    settings.displayConfiguration = UIScreen.mainScreen.displayConfiguration;
    settings.foreground = YES;
    
    settings.deviceOrientation = UIDevice.currentDevice.orientation;
    settings.interfaceOrientation = UIApplication.sharedApplication.statusBarOrientation;
    settings.frame = CGRectMake(0, 0, self.view.frame.size.height, self.view.frame.size.width);
    
    //settings.interruptionPolicy = 2; // reconnect
    settings.level = 1;
    settings.persistenceIdentifier = NSUUID.UUID.UUIDString;
    
    // it seems some apps don't honor these settings so we don't cover the top of the app
    settings.peripheryInsets = UIEdgeInsetsMake(0, 0, 0, 0);
    settings.safeAreaInsetsPortrait = UIEdgeInsetsMake(0, 0, 0, 0);
    
    settings.statusBarDisabled = YES;
    self.settings = settings;
    parameters.settings = settings;
    
    UIMutableApplicationSceneClientSettings *clientSettings = [UIMutableApplicationSceneClientSettings new];
    clientSettings.interfaceOrientation = UIInterfaceOrientationPortrait;
    clientSettings.statusBarStyle = 0;
    parameters.clientSettings = clientSettings;
    
    FBScene *scene = [[PrivClass(FBSceneManager) sharedInstance] createSceneWithDefinition:definition initialParameters:parameters];
    
    self.presenter = [scene.uiPresentationManager createPresenterWithIdentifier:self.sceneID];
    [self.presenter modifyPresentationContext:^(UIMutableScenePresentationContext *context) {
        context.appearanceStyle = 2;
    }];
    
    [self.view addSubview:self.presenter.presentationView];
    self.view.layer.anchorPoint = CGPointMake(0, 0);
    self.view.layer.position = CGPointMake(0, 0);

    [windowScene _registerSettingsDiffActionArray:@[self] forKey:self.sceneID];
    
    return YES;
}

- (void)closeWindowWithScene:(UIWindowScene*)windowScene
{
    [windowScene _unregisterSettingsDiffActionArrayForKey:self.sceneID];
    [_process terminate];
}

- (UIImage*)snapshotWindow
{
    LDEProcess *process = [[LDEProcessManager shared] processForProcessIdentifier:_processIdentifier];
    if(process == nil) return nil;
    return process.snapshot;
}

- (void)activateWindow
{
    // Set to foreground
    [self.presenter.scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
        settings.foreground = YES;
    }];
    
    [self.presenter activate];
    // Do it like on iOS, remove time window if applicable
    if(self.backgroundEnforcementTimer)
    {
        [self.backgroundEnforcementTimer invalidate];
        self.backgroundEnforcementTimer = nil;
    }
    
    // See if proc object needs to be altered
    kinfo_info_surface_t object = proc_object_for_pid(self.process.pid);
    if(object.force_task_role_override)
    {
        object.force_task_role_override = false;
        proc_object_insert(object);
    }
    
    // Resume if applicable
    [self.process resume];
}

- (void)deactivateWindow
{
    // Set to background
    [self.presenter.scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
        settings.foreground = NO;
    }];
    
    [self.process sendSignal:SIGUSR1];
    [self.presenter deactivate];
    
    // Do it like on iOS, give application time window for background tasks
    // TODO: Simulate darwinbg with wakeups and stuff in a certain time frame if the original app registered for it such as push notifications, etc
    self.backgroundEnforcementTimer = [NSTimer scheduledTimerWithTimeInterval:15.0 repeats:NO block:^(NSTimer *sender){
        if(!self.backgroundEnforcementTimer) return;
        if([self.process suspend])
        {
            // On iOS a app that gets suspended gets TASK_DARWINBG_APPLICATION assigned as task role
            kinfo_info_surface_t object = proc_object_for_pid(self.process.pid);
            if(object.real.kp_proc.p_pid == 0) return;
            object.force_task_role_override = true;
            object.task_role_override = TASK_DARWINBG_APPLICATION;
            proc_object_insert(object);
        }
    }];
}

- (void)windowChangesSizeToRect:(CGRect)rect
{
    // Handle user resizes
    [self.presenter.scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
        settings.deviceOrientation = UIDevice.currentDevice.orientation;
        settings.interfaceOrientation = self.view.window.windowScene.interfaceOrientation;
        
        if (UIInterfaceOrientationIsLandscape(settings.interfaceOrientation)) {
            settings.frame = CGRectMake(rect.origin.x, rect.origin.y, rect.size.height, rect.size.width);
        } else {
            settings.frame = rect;
        }
        if (self.pendingSettingsBlock) {
            self.pendingSettingsBlock(settings);
        }
    }];
}

- (void)sessionIdentifierAssigned:(int)identifier
{
    _process.windowIdentifier = identifier;
}

- (void)_performActionsForUIScene:(UIScene *)scene
              withUpdatedFBSScene:(id)fbsScene
                     settingsDiff:(FBSSceneSettingsDiff *)diff
                     fromSettings:(id)settings
                transitionContext:(id)context
              lifecycleActionType:(uint32_t)actionType
{
    if(![self.process.processHandle isValid])
    {
        //[self terminationCleanUp];
        return;
    }
    else if(self.process.isSuspended || !diff)
    {
        return;
    }
    
    UIMutableApplicationSceneSettings *baseSettings = [diff settingsByApplyingToMutableCopyOfSettings:settings];
    UIApplicationSceneTransitionContext *newContext = [context copy];
    newContext.actions = nil;
    
    UIMutableApplicationSceneSettings *newSettings = [self.presenter.scene.settings mutableCopy];
    newSettings.userInterfaceStyle = baseSettings.userInterfaceStyle;
    newSettings.interfaceOrientation = baseSettings.interfaceOrientation;
    newSettings.deviceOrientation = baseSettings.deviceOrientation;
    
    //[self.appSceneVC resizeActionStart];
    //[self.appSceneVC resizeActionEnd];
    
    [self.presenter.scene updateSettings:newSettings withTransitionContext:newContext completion:nil];
    
    //[self.delegate appSceneVC:self didUpdateFromSettings:baseSettings transitionContext:newContext];
}

- (void)encodeWithCoder:(nonnull NSCoder *)coder
{
}

- (void)traitCollectionDidChange:(nullable UITraitCollection *)previousTraitCollection
{
}

- (void)preferredContentSizeDidChangeForChildContentContainer:(nonnull id<UIContentContainer>)container
{
}

- (CGSize)sizeForChildContentContainer:(nonnull id<UIContentContainer>)container withParentContainerSize:(CGSize)parentSize
{
    return CGSizeZero;
}

- (void)systemLayoutFittingSizeDidChangeForChildContentContainer:(nonnull id<UIContentContainer>)container
{
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(nonnull id<UIViewControllerTransitionCoordinator>)coordinator
{
}

- (void)willTransitionToTraitCollection:(nonnull UITraitCollection *)newCollection withTransitionCoordinator:(nonnull id<UIViewControllerTransitionCoordinator>)coordinator
{
}

- (void)didUpdateFocusInContext:(nonnull UIFocusUpdateContext *)context withAnimationCoordinator:(nonnull UIFocusAnimationCoordinator *)coordinator
{
}

- (void)setNeedsFocusUpdate
{
}

- (BOOL)shouldUpdateFocusInContext:(nonnull UIFocusUpdateContext *)context
{
    return NO;
}

- (void)updateFocusIfNeeded
{
}

@end
