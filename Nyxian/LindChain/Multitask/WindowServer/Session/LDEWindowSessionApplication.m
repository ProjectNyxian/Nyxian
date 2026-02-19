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

#import <LindChain/Multitask/WindowServer/Session/LDEWindowSessionApplication.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/Multitask/WindowServer/LDEWindowServer.h>
#import <LindChain/Utils/Swizzle.h>

#if !JAILBREAK_ENV
#import <LindChain/Services/applicationmgmtd/LDEApplicationWorkspace.h>
#endif /* !JAILBREAK_ENV */

#import <LindChain/ProcEnvironment/Utils/klog.h>
#import <objc/runtime.h>
#import <os/lock.h>

@implementation RBSTarget(hook)

+ (instancetype)hook_targetWithPid:(pid_t)pid environmentIdentifier:(NSString *)environmentIdentifier
{
    if([environmentIdentifier containsString:@"LiveProcess"])
    {
        environmentIdentifier = [NSString stringWithFormat:@"LiveProcess:%d", pid];
    }
    return [self hook_targetWithPid:pid environmentIdentifier:environmentIdentifier];
}

@end

__attribute__((constructor))
void UIKitFixesInit(void)
{
    /* fix physical keyboard focus on iOS 17+ */
    if(@available(iOS 17.0, *))
    {
        method_exchangeImplementations(class_getClassMethod(RBSTarget.class, @selector(targetWithPid:environmentIdentifier:)), class_getClassMethod(RBSTarget.class, @selector(hook_targetWithPid:environmentIdentifier:)));
    }
}

@implementation LDEWindowSessionApplication {
    os_unfair_lock lock;
    BOOL isKeyboardShown;
    CGFloat keyboardBottomInset;
}

- (instancetype)initWithProcess:(LDEProcess*)process;
{
    self = [super init];
    _process = process;
    return self;
}

- (BOOL)openWindow
{
    if(![super openWindow])
    {
        return NO;
    }
    
    @try {
        self.presenter = [self.process.scene.uiPresentationManager createPresenterWithIdentifier:self.process.sceneID];
        [self.presenter modifyPresentationContext:^(UIMutableScenePresentationContext *context) {
            context.appearanceStyle = 2;
        }];
    } @catch (NSException *exception) {
#if !JAILBREAK_ENV
        klog_log(@"LDEWindowSessionApplication", @"presenter creation failed: %@", exception.reason);
#endif /* !JAILBREAK_ENV */
        return NO;
    }
    
    /* ready to show the presenter :3 */
    [self.view addSubview:self.presenter.presentationView];
    
    /* registering to window */
    [self.windowScene _registerSettingsDiffActionArray:@[self] forKey:self.process.sceneID];
    
    /* fixing keyboard issues */
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    
    /* initilize lock */
    lock = OS_UNFAIR_LOCK_INIT;
    
    return YES;
}

- (BOOL)closeWindow
{
    [super closeWindow];
    
    /* fixing keyboard issues */
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    /* invalidate presenter */
    [_presenter invalidate];
    
    /* unregistering scene lol */
    [self.windowScene _unregisterSettingsDiffActionArrayForKey:self.process.sceneID];
    
    /* terminating process so it stops eating our cores x3 */
    [_process terminate];
    
    return YES;
}

- (UIImage*)snapshotWindow
{
    if(_process == nil) return nil;
    return _process.snapshot;
}

- (BOOL)activateWindow
{
    os_unfair_lock_lock(&lock);
    
    /* set presenter to foreground */
    [self.presenter.scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
        settings.foreground = YES;
    }];
    
    /* re-activate presenter */
    [self.presenter activate];
    
    /* invalidate background enforcement timer if applicable */
    if(self.backgroundEnforcementTimer)
    {
        [self.backgroundEnforcementTimer invalidate];
        self.backgroundEnforcementTimer = nil;
    }
    
    /* resume process */
    [self.process resume];
    
    os_unfair_lock_unlock(&lock);
    
    return YES;
}

- (BOOL)deactivateWindow
{
    os_unfair_lock_lock(&lock);
    
    /* set presenter to background */
    [self.presenter.scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
        settings.foreground = NO;
    }];
 
    /* TODO: implement the jailbreak way of getting a snapshot of a iOS app */
#if !JAILBREAK_ENV
    [self.process sendSignal:SIGUSR1];
#endif /* !JAILBREAK_ENV */
    
    /* deactivate the presenter */
    [self.presenter deactivate];
    
    // Do it like on iOS, give application time window for background tasks
    self.backgroundEnforcementTimer = [NSTimer scheduledTimerWithTimeInterval:15.0 repeats:NO block:^(NSTimer *sender){
        if(!self.backgroundEnforcementTimer) return;
        [self.process suspend];
    }];
    
    os_unfair_lock_unlock(&lock);
    
    return YES;
}

- (void)windowChangesToRect:(CGRect)rect
{
    [super windowChangesToRect:rect];
    
    os_unfair_lock_lock(&lock);
    
    if(self.process.isSuspended)
    {
        os_unfair_lock_unlock(&lock);
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    
    /* update window dimensions */
    [self.presenter.scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {

        settings.deviceOrientation = UIDevice.currentDevice.orientation;
        settings.interfaceOrientation = self.view.window.windowScene.interfaceOrientation;
        settings.frame = UIInterfaceOrientationIsLandscape(settings.interfaceOrientation) ? CGRectMake(rect.origin.x, rect.origin.y, rect.size.height, rect.size.width) : rect;
        
        UIEdgeInsets insets = (self.isFullscreen) ? LDEWindowServer.shared.safeAreaInsets : UIEdgeInsetsZero;
        
        /* looks unnatural without */
        insets.top = 10;
        
        __strong typeof(self) innerSelf = weakSelf;
        if(innerSelf->isKeyboardShown)
        {
            insets.bottom = innerSelf->keyboardBottomInset - rect.origin.y;
        }
        
        switch(settings.interfaceOrientation)
        {
            case UIInterfaceOrientationPortrait:
                settings.safeAreaInsetsPortrait = insets;
                break;
            case UIInterfaceOrientationPortraitUpsideDown:
                settings.safeAreaInsetsPortraitUpsideDown = insets;
                break;
            case UIInterfaceOrientationLandscapeLeft:
                settings.safeAreaInsetsLandscapeLeft = insets;
                break;
            case UIInterfaceOrientationLandscapeRight:
                settings.safeAreaInsetsLandscapeRight = insets;
            case UIInterfaceOrientationUnknown:
                break;
        }
    }];
    
    os_unfair_lock_unlock(&lock);
}

- (void)sessionIdentifierAssigned:(int)identifier
{
    _process.wid = identifier;
}

- (void)_performActionsForUIScene:(UIScene *)scene
              withUpdatedFBSScene:(id)fbsScene
                     settingsDiff:(FBSSceneSettingsDiff *)diff
                     fromSettings:(id)settings
                transitionContext:(id)context
              lifecycleActionType:(uint32_t)actionType
{
    os_unfair_lock_lock(&lock);
    
    if(![self.process.processHandle isValid] || self.process.isSuspended || !diff)
    {
        os_unfair_lock_unlock(&lock);
        return;
    }
    
    UIMutableApplicationSceneSettings *baseSettings = [diff settingsByApplyingToMutableCopyOfSettings:settings];
    UIApplicationSceneTransitionContext *newContext = [context copy];
    newContext.actions = nil;
    
    UIMutableApplicationSceneSettings *newSettings = [self.presenter.scene.settings mutableCopy];
    newSettings.userInterfaceStyle = baseSettings.userInterfaceStyle;
    
    [self.presenter.scene updateSettings:newSettings withTransitionContext:newContext completion:nil];
    
    os_unfair_lock_unlock(&lock);
    
    [self windowChangesToRect:self.windowRect];
}

- (BOOL)shouldUpdateFocusInContext:(nonnull UIFocusUpdateContext *)context
{
    return NO;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
 
    os_unfair_lock_lock(&lock);
    
    if(![self.process.processHandle isValid] || self.process.isSuspended)
    {
        os_unfair_lock_unlock(&lock);
        return;
    }
    
    if(self.traitCollection.userInterfaceStyle != previousTraitCollection.userInterfaceStyle)
    {
        [self.presenter.scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
            settings.userInterfaceStyle = self.traitCollection.userInterfaceStyle;
        }];
    }
    
    os_unfair_lock_unlock(&lock);
}

- (void)keyboardWillShow:(NSNotification *)notification
{
    os_unfair_lock_lock(&lock);
    
    NSDictionary *info = notification.userInfo;
    CGRect keyboardFrame = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    
    CGFloat bottomInset = keyboardFrame.size.height;
    
    if(![self.process.processHandle isValid] || self.process.isSuspended)
    {
        os_unfair_lock_unlock(&lock);
        return;
    }
    
    [self.presenter.scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
        UIEdgeInsets currentInsets = settings.safeAreaInsetsPortrait;
        currentInsets.bottom = bottomInset;
        
        
        settings.safeAreaInsetsPortrait = currentInsets;
        settings.safeAreaInsetsLandscapeLeft = currentInsets;
        settings.safeAreaInsetsLandscapeRight = currentInsets;
        settings.safeAreaInsetsPortraitUpsideDown = currentInsets;
    }];
    
    isKeyboardShown = true;
    
    os_unfair_lock_unlock(&lock);
}

- (void)keyboardWillHide:(NSNotification *)notification
{
    os_unfair_lock_lock(&lock);
    
    if(![self.process.processHandle isValid] || self.process.isSuspended)
    {
        os_unfair_lock_unlock(&lock);
        return;
    }
    
    [self.presenter.scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
        UIEdgeInsets currentInsets = settings.safeAreaInsetsPortrait;
        
        if(self.isFullscreen)
        {
            currentInsets.bottom = LDEWindowServer.shared.safeAreaInsets.bottom;
        }
        else
        {
            currentInsets.bottom = 0;
        }
        
        settings.safeAreaInsetsPortrait = currentInsets;
        settings.safeAreaInsetsLandscapeLeft = currentInsets;
        settings.safeAreaInsetsLandscapeRight = currentInsets;
        settings.safeAreaInsetsPortraitUpsideDown = currentInsets;
    }];
    
    isKeyboardShown = false;
    
    os_unfair_lock_unlock(&lock);
}

- (NSString*)windowName
{
    return self.process.displayName;
}

- (void)prepareForInject
{
    /* making sure LDEProcess wont close this */
    self.process.wid = (wid_t)-1;
    self.process.session = nil;
}

- (BOOL)injectProcess:(LDEProcess*)process
{
    os_unfair_lock_lock(&lock);
    
    /* keep reference to old presenter for animation */
    UIView *oldPresentationView = self.presenter.presentationView;
    _UIScenePresenter *oldPresenter = self.presenter;
    
    /* unregister old window */
    [self.windowScene _unregisterSettingsDiffActionArrayForKey:self.process.sceneID];
    
    self.process = process;
    
    @try {
        self.presenter = [self.process.scene.uiPresentationManager createPresenterWithIdentifier:process.sceneID];
        [self.presenter modifyPresentationContext:^(UIMutableScenePresentationContext *context) {
            context.appearanceStyle = 2;
        }];
    } @catch (NSException *exception) {
#if !JAILBREAK_ENV
        klog_log(@"LDEWindowSessionApplication", @"presenter creation failed: %@", exception.reason);
#endif /* !JAILBREAK_ENV */
        os_unfair_lock_unlock(&lock);
        return NO;
    }
    
    /* setup new presenter view with initial alpha */
    UIView *newPresentationView = self.presenter.presentationView;
    newPresentationView.alpha = 0.0;
    
    /* add new view below old view */
    if(oldPresentationView)
    {
        [self.view insertSubview:newPresentationView belowSubview:oldPresentationView];
    }
    else
    {
        [self.view addSubview:newPresentationView];
    }
    
    /* register new window */
    [self.windowScene _registerSettingsDiffActionArray:@[self] forKey:process.sceneID];
    
    os_unfair_lock_unlock(&lock);
    
    [self windowChangesToRect:self.windowRect];
    
    /* animate transition */
    [UIView animateWithDuration:0.3 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        newPresentationView.alpha = 1.0;
        if(oldPresentationView)
        {
            oldPresentationView.alpha = 0.0;
        }
    } completion:^(BOOL finished) {
        /* cleanup old presenter */
        [oldPresentationView removeFromSuperview];
        [oldPresenter invalidate];
    }];
    
    return YES;
}

- (void)dealloc
{
    NSLog(@"deallocated %@", self);
}

@end

void LDEBringApplicationSessionToFrontAssosiatedWithBundleIdentifier(NSString *bundleIdentifier)
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if(UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPad) return;
        LDEWindowServer *windowServer = [LDEWindowServer shared];
        if(windowServer == nil) return;
        
        for(NSNumber *key in windowServer.windows)
        {
            LDEWindow *window = windowServer.windows[key];
            if(window == nil) continue;
            if([window.session isKindOfClass:[LDEWindowSessionApplication class]])
            {
                LDEWindowSessionApplication *session = (LDEWindowSessionApplication*)window.session;
                if([session.process.bundleIdentifier isEqualToString:bundleIdentifier])
                {
                    [window.view.superview bringSubviewToFront:window.view];
                    break;
                }
            }
        }
    });
}
