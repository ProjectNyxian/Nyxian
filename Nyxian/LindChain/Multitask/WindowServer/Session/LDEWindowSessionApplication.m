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

#if !JAILBREAK_ENV
#import <LindChain/Services/applicationmgmtd/LDEApplicationWorkspace.h>
#endif /* !JAILBREAK_ENV */

#import <LindChain/ProcEnvironment/Utils/klog.h>
#import <objc/runtime.h>

NSMutableDictionary<NSString*,NSValue*> *runtimeStoredRectValuesByBundleIdentifier;

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

@implementation LDEWindowSessionApplication

@synthesize windowName;
@synthesize windowIsFullscreen;

- (instancetype)initWithProcess:(LDEProcess*)process;
{
    self = [super init];
    _process = process;

    self.windowName  = self.process.displayName;

    return self;
}

- (BOOL)openWindowWithScene:(UIWindowScene*)windowScene
      withSessionIdentifier:(int)identifier
{
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
    [windowScene _registerSettingsDiffActionArray:@[self] forKey:self.process.sceneID];
    
    /* fixing keyboard issues */
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(keyboardWillHide:) name:UIKeyboardWillHideNotification object:nil];
    
    return YES;
}

- (void)closeWindowWithScene:(UIWindowScene*)windowScene
                   withFrame:(CGRect)rect;
{
    /* checking for bundle identifier presence */
    if(_process.bundleIdentifier != nil)
    {
        /* if so then we store the last rect ever into this database */
        runtimeStoredRectValuesByBundleIdentifier[_process.bundleIdentifier] = [NSValue valueWithCGRect:rect];
    }
    
    /* fixing keyboard issues */
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    /* invalidate presenter */
    [_presenter invalidate];
    
    /* unregistering scene lol */
    [windowScene _unregisterSettingsDiffActionArrayForKey:self.process.sceneID];
    
    /* terminating process so it stops eating our cores x3 */
    [_process terminate];
}

- (UIImage*)snapshotWindow
{
    if(_process == nil) return nil;
    return _process.snapshot;
}

- (void)activateWindow
{
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
}

- (void)deactivateWindow
{
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
}

- (void)windowChangesSizeToRect:(CGRect)rect
{
    // MARK: Has to be set so _performActionsForUIScene works
    self.windowSize = rect;
    
    // Handle user resizes
    [self.presenter.scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
        settings.deviceOrientation = UIDevice.currentDevice.orientation;
        settings.interfaceOrientation = self.view.window.windowScene.interfaceOrientation;
        
        if(UIInterfaceOrientationIsLandscape(settings.interfaceOrientation))
        {
            settings.frame = CGRectMake(rect.origin.x, rect.origin.y, rect.size.height, rect.size.width);
        }
        else
        {
            settings.frame = rect;
        }
        
        UIEdgeInsets insets = UIEdgeInsetsZero;
        if(self.windowIsFullscreen)
        {
            insets = LDEWindowServer.shared.safeAreaInsets;
        }
        else
        {
            insets = UIEdgeInsetsZero;
        }
        
        insets.top = 10;
        
        settings.safeAreaInsetsPortrait = insets;
        settings.safeAreaInsetsLandscapeLeft = insets;
        settings.safeAreaInsetsLandscapeRight = insets;
        settings.safeAreaInsetsPortraitUpsideDown = insets;
    }];
}

- (void)sessionIdentifierAssigned:(int)identifier
{
    _process.wid = identifier;
}

- (void)_performActionsForUIScene:(UIScene *)scene  /* TODO: worth investigation.. it exposes a UIScene object */
              withUpdatedFBSScene:(id)fbsScene
                     settingsDiff:(FBSSceneSettingsDiff *)diff
                     fromSettings:(id)settings
                transitionContext:(id)context
              lifecycleActionType:(uint32_t)actionType
{
    if(![self.process.processHandle isValid] || self.process.isSuspended || !diff)
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
    
    if(UIInterfaceOrientationIsLandscape(newSettings.interfaceOrientation))
    {
        newSettings.frame = CGRectMake(self.windowSize.origin.x, self.windowSize.origin.y, self.windowSize.size.height, self.windowSize.size.width);
    }
    else
    {
        newSettings.frame = self.windowSize;
    }
    
    [self.presenter.scene updateSettings:newSettings withTransitionContext:newContext completion:nil];
    
    [self windowChangesSizeToRect:self.windowSize];
}

- (CGSize)sizeForChildContentContainer:(nonnull id<UIContentContainer>)container withParentContainerSize:(CGSize)parentSize
{
    return CGSizeZero;
}

- (BOOL)shouldUpdateFocusInContext:(nonnull UIFocusUpdateContext *)context
{
    return NO;
}

- (CGRect)windowRect
{
    NSValue *nsValue = runtimeStoredRectValuesByBundleIdentifier[_process.bundleIdentifier];
    if(nsValue == nil)
    {
        return CGRectMake(50, 50, 400, 400);
    }
    else
    {
        return nsValue.CGRectValue;
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    
    if(self.traitCollection.userInterfaceStyle != previousTraitCollection.userInterfaceStyle)
    {
        [self.presenter.scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
            settings.userInterfaceStyle = self.traitCollection.userInterfaceStyle;
        }];
    }
}

- (void)keyboardWillShow:(NSNotification *)notification
{
    NSDictionary *info = notification.userInfo;
    CGRect keyboardFrame = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    
    [self.presenter.scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
        UIEdgeInsets currentInsets = settings.safeAreaInsetsPortrait;
        currentInsets.bottom = keyboardFrame.size.height;
        settings.safeAreaInsetsPortrait = currentInsets;
    }];
}

- (void)keyboardWillHide:(NSNotification *)notification
{
    [self.presenter.scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
        UIEdgeInsets currentInsets = settings.safeAreaInsetsPortrait;
        
        if(self.windowIsFullscreen)
        {
            currentInsets.bottom = LDEWindowServer.shared.safeAreaInsets.bottom;
        }
        else
        {
            currentInsets.bottom = 0;
        }
        
        settings.safeAreaInsetsPortrait = currentInsets;
    }];
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
