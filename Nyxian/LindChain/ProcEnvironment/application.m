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
#import <LindChain/ProcEnvironment/proxy.h>
#import <LindChain/ProcEnvironment/Surface/sys/syscall.h>
#import <LindChain/ProcEnvironment/syscall.h>

#pragma mark - Audio background mode fix (Fixes playing music in spotify while spotify is not in nyxians foreground)

@implementation AVAudioSession (ProcEnvironment)

- (BOOL)hook_setActive:(BOOL)active error:(NSError*)outError
{
    environment_syscall(SYS_bamset, active);
    return [self hook_setActive:active error:outError];
}

- (BOOL)hook_setActive:(BOOL)active withOptions:(AVAudioSessionSetActiveOptions)options error:(NSError **)outError
{
    environment_syscall(SYS_bamset, active);
    return [self hook_setActive:active withOptions:options error:outError];
}


@end


#pragma mark - Initilizer

void environment_signal_child_handler(int code)
{
    UIApplication *sharedApplication = [PrivClass(UIApplication) sharedApplication];
    
    if(sharedApplication)
    {
        if(code == SIGUSR1)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                // TODO: Shall be done by the runLoop and not by the handler, this could lead to some strange behaviour
                
                /* finding active scene */
                UIWindowScene *activeScene = nil;
                for(UIWindowScene *scene in sharedApplication.connectedScenes)
                {
                    if(scene.activationState == UISceneActivationStateForegroundActive)
                    {
                        activeScene = scene;
                        break;
                    }
                }

                /* null pointer check */
                if(!activeScene)
                {
                    return;
                }
                
                /* getting view we wanna capture with our own eyes ^^ */
                UIWindow *rootWindow = activeScene.keyWindow;
                UIViewController *topVC = rootWindow.rootViewController;
                UIView *viewToCapture = topVC.view ?: rootWindow;
                
                /* preparing format for renderer */
                CGFloat scale = [UIScreen mainScreen].scale;
                UIGraphicsImageRendererFormat *format = [UIGraphicsImageRendererFormat defaultFormat];
                format.scale = scale;
                format.opaque = viewToCapture.isOpaque;
                
                /* creating renderer */
                UIGraphicsImageRenderer *renderer = [[UIGraphicsImageRenderer alloc] initWithSize:viewToCapture.bounds.size format:format];
                
                /* and snapshotting... */
                UIImage *snapshot = [renderer imageWithActions:^(UIGraphicsImageRendererContext * _Nonnull rendererContext) {
                    /* crafting screenshot */
                    [viewToCapture drawViewHierarchyInRect:viewToCapture.bounds afterScreenUpdates:YES];
                }];
                
                /* sending to host */
                environment_proxy_set_snapshot(snapshot);
                
                /* notifying application/scene delegate about background entrance */
                if(sharedApplication.connectedScenes.count > 0)
                {
                    /* its scene based */
                    for(UIWindowScene *scene in sharedApplication.connectedScenes)
                    {
                        if(![scene isKindOfClass:[UIWindowScene class]])
                        {
                            continue;
                        }
                        
                        [[NSNotificationCenter defaultCenter] postNotificationName:UISceneWillDeactivateNotification object:scene];
                        [[NSNotificationCenter defaultCenter] postNotificationName:UISceneDidEnterBackgroundNotification object:scene];
                    }
                }
                else
                {
                    /* ugh a legacyyy iOS app again */
                    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationWillResignActiveNotification object:sharedApplication];
                    [[NSNotificationCenter defaultCenter] postNotificationName:UIApplicationDidEnterBackgroundNotification object:sharedApplication];
                }
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
        swizzle_objc_method(@selector(setActive:error:), [AVAudioSession class], @selector(hook_setActive:error:), nil);
        swizzle_objc_method(@selector(setActive:withOptions:error:), [AVAudioSession class], @selector(hook_setActive:withOptions:error:), nil);
        
        signal(SIGUSR1, environment_signal_child_handler);
    }
}
