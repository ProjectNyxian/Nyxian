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

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <LindChain/ProcEnvironment/application.h>
#import <LindChain/ProcEnvironment/environment.h>
#import <LindChain/Utils/Swizzle.h>

#pragma mark - UIApplication entry detection (Used to trigger window apparance, headless processes basically)

@implementation UIApplication (ProcEnvironment)

- (void)hook_run
{
    // Only allow client processing
    if(environment_is_role(EnvironmentRoleGuest))
    {
        // Tell host app to let our process appear
        if(!environment_proxy_make_window_visible()) exit(0);
    }
    
    [self hook_run];
}

@end

#pragma mark - Audio background mode fix (Fixes playing music in spotify while spotify is not in nyxians foreground)

@implementation AVAudioSession (ProcEnvironment)

- (BOOL)hook_setActive:(BOOL)active error:(NSError*)outError
{
    [hostProcessProxy setAudioBackgroundModeActive:active];
    return [self hook_setActive:active error:outError];
}

- (BOOL)hook_setActive:(BOOL)active withOptions:(AVAudioSessionSetActiveOptions)options error:(NSError **)outError
{
    [hostProcessProxy setAudioBackgroundModeActive:active];
    return [self hook_setActive:active withOptions:options error:outError];
}


@end


#pragma mark - Initilizer

UIViewController *TopViewController(UIViewController *rootVC) {
    if (rootVC.presentedViewController) {
        return TopViewController(rootVC.presentedViewController);
    }
    if ([rootVC isKindOfClass:[UINavigationController class]]) {
        UINavigationController *nav = (UINavigationController *)rootVC;
        return TopViewController(nav.visibleViewController);
    }
    if ([rootVC isKindOfClass:[UITabBarController class]]) {
        UITabBarController *tab = (UITabBarController *)rootVC;
        return TopViewController(tab.selectedViewController);
    }
    return rootVC;
}

void environment_signal_child_handler(int code)
{
    UIApplication *sharedApplication = [PrivClass(UIApplication) sharedApplication];
    
    if(sharedApplication)
    {
        if(code == SIGUSR1)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                // TODO: Shall be done by the runLoop and not by the handler, this could lead to some strange behaviour
                UIWindow *keyWindow = nil;
                for(UIWindowScene *scene in sharedApplication.connectedScenes)
                {
                    if(scene.activationState == UISceneActivationStateForegroundActive)
                    {
                        keyWindow = scene.windows.firstObject;
                        break;
                    }
                }
                if(!keyWindow)
                {
                    keyWindow = sharedApplication.keyWindow;
                }
                
                UIView *rootView = keyWindow.rootViewController.view;
                
                UIViewController *topVC = keyWindow.rootViewController;
                UIView *viewToCapture = topVC.view ?: rootView;
                
                CGFloat scale = [UIScreen mainScreen].scale;
                UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
                format.scale = scale;
                format.opaque = viewToCapture.isOpaque;
                
                UIGraphicsImageRenderer *renderer =
                [[UIGraphicsImageRenderer alloc] initWithSize:viewToCapture.bounds.size format:format];
                
                UIImage *snapshot = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
                    [viewToCapture.layer renderInContext:rendererContext.CGContext];
                }];
                environment_proxy_set_snapshot(snapshot);
                
                // TODO: Signal didEnterBackground
                //[[sharedApplication delegate] applicationDidEnterBackground:sharedApplication];*/
            });
        }
        return;
    }
}

void environment_application_init(void)
{
    if(environment_is_role(EnvironmentRoleGuest))
    {
        // MARK: GUEST Init
        // MARK: Hooking _run of UIApplication class seems more reliable
        swizzle_objc_method(@selector(_run), [UIApplication class], @selector(hook_run), nil);
        swizzle_objc_method(@selector(setActive:error:), [AVAudioSession class], @selector(hook_setActive:error:), nil);
        swizzle_objc_method(@selector(setActive:withOptions:error:), [AVAudioSession class], @selector(hook_setActive:withOptions:error:), nil);
        
        signal(SIGUSR1, environment_signal_child_handler);
        signal(SIGUSR2, environment_signal_child_handler);
    }
}
