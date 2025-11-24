#import <UIKit/UIKit.h>
#import "../LCUtils.h"
#import "UIKitPrivate.h"
#import "utils.h"
#import <LocalAuthentication/LocalAuthentication.h>
#import <LindChain/Utils/Swizzle.h>
#import <objc/message.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wundeclared-selector"

// Handler for AppDelegate
@implementation UIApplication(LiveContainerHook)

- (void)hook__connectUISceneFromFBSScene:(id)scene transitionContext:(UIApplicationSceneTransitionContext*)context {
#if !TARGET_OS_MACCATALYST
    context.payload = nil;
    context.actions = nil;
#endif
    [self hook__connectUISceneFromFBSScene:scene transitionContext:context];
}

- (void)hook_setDelegate:(id<UIApplicationDelegate>)delegate {
    if(![delegate respondsToSelector:@selector(application:configurationForConnectingSceneSession:options:)]) {
        // Fix old apps black screen when UIApplicationSupportsMultipleScenes is YES
        swizzle_objc_method(@selector(makeKeyAndVisible), [UIWindow class], @selector(hook_makeKeyAndVisible), nil);
        swizzle_objc_method(@selector(makeKeyWindow), [UIWindow class], @selector(hook_makeKeyWindow), nil);
        swizzle_objc_method(@selector(setHidden:), [UIWindow class], @selector(hook_setHidden:), nil);
    }
    [self hook_setDelegate:delegate];
}

+ (BOOL)_wantsApplicationBehaviorAsExtension {
    // Fix LiveProcess: Make _UIApplicationWantsExtensionBehavior return NO so delegate code runs in the run loop
    return YES;
}

@end

@interface UIViewController ()

- (UIInterfaceOrientationMask)__supportedInterfaceOrientations;

@end

@implementation UIViewController (LiveContainerHook)

- (UIInterfaceOrientationMask)hook___supportedInterfaceOrientations {
    return UIInterfaceOrientationMaskAll;
}

- (BOOL)hook_shouldAutorotateToInterfaceOrientation:(NSInteger)orientation {
    return YES;
}

@end

@implementation UIWindow (LiveContainerHook)
- (void)hook_setAutorotates:(BOOL)autorotates forceUpdateInterfaceOrientation:(BOOL)force {
    [self hook_setAutorotates:YES forceUpdateInterfaceOrientation:YES];
}

- (void)hook_makeKeyAndVisible {
    [self updateWindowScene];
    [self hook_makeKeyAndVisible];
}
- (void)hook_makeKeyWindow {
    [self updateWindowScene];
    [self hook_makeKeyWindow];
}
- (void)hook_resignKeyWindow {
    [self updateWindowScene];
    [self hook_resignKeyWindow];
}
- (void)hook_setHidden:(BOOL)hidden {
    [self updateWindowScene];
    [self hook_setHidden:hidden];
}
- (void)updateWindowScene {
    UIApplication *app = ((UIApplication *(*)(id, SEL))objc_msgSend)(NSClassFromString(@"UIApplication"), NSSelectorFromString(@"sharedApplication"));
    for(UIWindowScene *windowScene in app.connectedScenes) {
        if(!self.windowScene && self.screen == windowScene.screen) {
            self.windowScene = windowScene;
            break;
        }
    }
}
@end

void UIKitGuestHooksInit(void)
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        swizzle_objc_method(@selector(_connectUISceneFromFBSScene:transitionContext:), [UIApplication class], @selector(hook__connectUISceneFromFBSScene:transitionContext:), nil);
        swizzle_objc_method(@selector(setDelegate:), [UIApplication class], @selector(hook_setDelegate:), nil);
        swizzle_objc_method(@selector(__supportedInterfaceOrientations), [UIViewController class], @selector(hook___supportedInterfaceOrientations), nil);
        swizzle_objc_method(@selector(shouldAutorotateToInterfaceOrientation:), [UIViewController class], @selector(hook_shouldAutorotateToInterfaceOrientation:), nil);
        swizzle_objc_method(@selector(setAutorotates:forceUpdateInterfaceOrientation:), [UIWindow class], @selector(hook_setAutorotates:forceUpdateInterfaceOrientation:), nil);
    });
}

#pragma clang diagnostic pop
