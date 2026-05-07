/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2023 - 2026 LiveContainer
 Copyright (C) 2026 mach-port-t

 This file is part of LiveContainer.

 LiveContainer is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 LiveContainer is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#import <UIKit/UIKit.h>
#import "../LCUtils.h"
#import "UIKitPrivate.h"
#import "utils.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import <LindChain/Utils/Swizzle.h>
#import <objc/message.h>

// Handler for AppDelegate
@implementation UIApplication(LiveContainerHook)

- (void)hook__connectUISceneFromFBSScene:(id)scene transitionContext:(UIApplicationSceneTransitionContext*)context
{
#if !TARGET_OS_MACCATALYST
    context.payload = nil;
    context.actions = nil;
#endif
    [self hook__connectUISceneFromFBSScene:scene transitionContext:context];
}

+ (BOOL)_wantsApplicationBehaviorAsExtension
{
    // Fix LiveProcess: Make _UIApplicationWantsExtensionBehavior return NO so delegate code runs in the run loop
    return YES;
}

@end

@interface UIViewController ()

- (UIInterfaceOrientationMask)__supportedInterfaceOrientations;

@end

@implementation UIViewController (LiveContainerHook)

- (UIInterfaceOrientationMask)hook___supportedInterfaceOrientations
{
    return UIInterfaceOrientationMaskAll;
}

- (BOOL)hook_shouldAutorotateToInterfaceOrientation:(NSInteger)orientation
{
    return YES;
}

@end

@implementation UIWindow (LiveContainerHook)

- (void)hook_setAutorotates:(BOOL)autorotates forceUpdateInterfaceOrientation:(BOOL)force
{
    [self hook_setAutorotates:YES forceUpdateInterfaceOrientation:YES];
}

@end

void UIKitGuestHooksInit(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"
        swizzle_objc_method(@selector(_connectUISceneFromFBSScene:transitionContext:), [UIApplication class], @selector(hook__connectUISceneFromFBSScene:transitionContext:), nil);
#pragma clang diagnostic pop
        swizzle_objc_method(@selector(__supportedInterfaceOrientations), [UIViewController class], @selector(hook___supportedInterfaceOrientations), nil);
        swizzle_objc_method(@selector(shouldAutorotateToInterfaceOrientation:), [UIViewController class], @selector(hook_shouldAutorotateToInterfaceOrientation:), nil);
        swizzle_objc_method(@selector(setAutorotates:forceUpdateInterfaceOrientation:), [UIWindow class], @selector(hook_setAutorotates:forceUpdateInterfaceOrientation:), nil);
    });
}
