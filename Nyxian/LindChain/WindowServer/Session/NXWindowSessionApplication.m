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

#import <LindChain/WindowServer/Session/NXWindowSessionApplication.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/WindowServer/NXWindowServer.h>
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

@implementation NXWindowSessionApplication {
    os_unfair_lock _lock;
}

- (instancetype)initWithProcess:(PEProcess*)process;
{
    self = [super init];
    _process = process;
    _lock = OS_UNFAIR_LOCK_INIT;
    return self;
}

+ (void)bringSessionToFrontWithBundleIdentifier:(NSString*)bundleIdentifier
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if(UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPad) return;
        NXWindowServer *windowServer = [NXWindowServer shared];
        assert(windowServer != nil);
        
        for(NSNumber *key in windowServer.windows)
        {
            NXWindow *window = windowServer.windows[key];
            
            if(window != nil &&
               [window.session isKindOfClass:[NXWindowSessionApplication class]] &&
               [((NXWindowSessionApplication*)(window.session)).process.bundleIdentifier isEqualToString:bundleIdentifier])
            {
                [window.view.superview bringSubviewToFront:window.view];
                [window focusWindow];
                break;
            }
        }
    });
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
    
    return YES;
}

- (BOOL)closeWindow
{
    [super closeWindow];
    
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
    os_unfair_lock_lock(&_lock);
    
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
    
    os_unfair_lock_unlock(&_lock);
    
    return YES;
}

- (BOOL)deactivateWindow
{
    os_unfair_lock_lock(&_lock);
    
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
    __weak typeof(self) weakSelf = self;
    self.backgroundEnforcementTimer = [NSTimer scheduledTimerWithTimeInterval:15.0 repeats:NO block:^(NSTimer *sender){
        __strong typeof(self) innerSelf = weakSelf;
        if(innerSelf == nil)
        {
            return;
        }
        
        if(!innerSelf.backgroundEnforcementTimer) return;
        [innerSelf.process suspend];
    }];
    
    os_unfair_lock_unlock(&_lock);
    
    return YES;
}

- (void)windowChangesToRect:(CGRect)rect
{
    [super windowChangesToRect:rect];
    
    if(UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad)
    {
        rect = CGRectMake(0, 0, rect.size.width, rect.size.height);
    }
    
    os_unfair_lock_lock(&_lock);
    
    if(self.process.isSuspended)
    {
        os_unfair_lock_unlock(&_lock);
        return;
    }
    
    __weak typeof(self) weakSelf = self;
    
    /* update window dimensions */
    [self.presenter.scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {

        settings.deviceOrientation = UIDevice.currentDevice.orientation;
        settings.interfaceOrientation = self.view.window.windowScene.interfaceOrientation;
        settings.frame = UIInterfaceOrientationIsLandscape(settings.interfaceOrientation) ? CGRectMake(rect.origin.x, rect.origin.y, rect.size.height, rect.size.width) : rect;
        
        UIEdgeInsets insets = (self.isFullscreen) ? NXWindowServer.shared.safeAreaInsets : UIEdgeInsetsZero;
        
        /* looks unnatural without */
        insets.top = 10;
        
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
    
    os_unfair_lock_unlock(&_lock);
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
    os_unfair_lock_lock(&_lock);
    
    if(![self.process.processHandle isValid] || self.process.isSuspended || !diff)
    {
        os_unfair_lock_unlock(&_lock);
        return;
    }
    
    UIMutableApplicationSceneSettings *baseSettings = [diff settingsByApplyingToMutableCopyOfSettings:settings];
    UIApplicationSceneTransitionContext *newContext = [context copy];
    newContext.actions = nil;
    
    UIMutableApplicationSceneSettings *newSettings = [self.presenter.scene.settings mutableCopy];
    newSettings.userInterfaceStyle = baseSettings.userInterfaceStyle;
    
    [self.presenter.scene updateSettings:newSettings withTransitionContext:newContext completion:nil];
    
    os_unfair_lock_unlock(&_lock);
    
    [self windowChangesToRect:self.windowRect];
}

- (BOOL)shouldUpdateFocusInContext:(nonnull UIFocusUpdateContext *)context
{
    return NO;
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
 
    os_unfair_lock_lock(&_lock);
    
    if(![self.process.processHandle isValid] || self.process.isSuspended)
    {
        os_unfair_lock_unlock(&_lock);
        return;
    }
    
    if(self.traitCollection.userInterfaceStyle != previousTraitCollection.userInterfaceStyle)
    {
        [self.presenter.scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
            settings.userInterfaceStyle = self.traitCollection.userInterfaceStyle;
        }];
    }
    
    os_unfair_lock_unlock(&_lock);
}

- (NSString*)windowName
{
    return self.process.displayName;
}

- (void)prepareForInject
{
    /* making sure LDEProcess wont close this */
    self.process.wid = (id_t)-1;
    self.process.session = nil;
}

- (BOOL)injectProcess:(PEProcess*)process
{
    os_unfair_lock_lock(&_lock);
    
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
        os_unfair_lock_unlock(&_lock);
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
    
    os_unfair_lock_unlock(&_lock);
    
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

- (NSString*)getWindowName
{
    NSString *windowName = [super getWindowName];
    return windowName ?: self.process.displayName;
}

- (void)dealloc
{
    NSLog(@"deallocated %@", self);
}

@end
