/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2025 - 2026 emexlab

 This file is part of Nyxian.

 Licensed under the emexLabs Public Source License, version 1.1
 (EPSL 1.1).

 Private use and modification are permitted under the license.
 Redistribution of source or binaries, modified or unmodified,
 requires prior written permission from emexLabs.

 External deployment is subject to the source-availability
 requirements and other conditions of the license.

 Provided "AS IS", without warranty, to the extent permitted by law.

 See LICENSE for the full license terms.
*/

#import <LindChain/IDEFoundation/NXAlertDiagnosticPresenter.h>
#import <LindChain/WindowServer/NXWindowServer.h>

static UIViewController *NXTopViewController(UIViewController *viewController)
{
    if(viewController.presentedViewController)
    {
        return NXTopViewController(viewController.presentedViewController);
    }
    
    if([viewController isKindOfClass:[UINavigationController class]])
    {
        UINavigationController *nav = (UINavigationController *)viewController;
        return NXTopViewController(nav.visibleViewController ?: nav);
    }
    
    if([viewController isKindOfClass:[UITabBarController class]])
    {
        UITabBarController *tab = (UITabBarController *)viewController;
        return NXTopViewController(tab.selectedViewController ?: tab);
    }
    
    return viewController;
}

static NSString *NXStringForNXAlertDiagnosticPresenterLevel(NXAlertDiagnosticPresenterLevel level)
{
    switch(level)
    {
        case NXAlertDiagnosticPresenterLevelNote:
            return @"Note";
        case NXAlertDiagnosticPresenterLevelWarning:
            return @"Warning";
        case NXAlertDiagnosticPresenterLevelError:
        default:
            return @"Error";
    }
}

@implementation NXAlertDiagnosticPresenter

+ (void)notifyUserWithLevel:(NXAlertDiagnosticPresenterLevel)level
                withMessage:(NSString*)message
                  withDelay:(double)delay
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delay), dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
        dispatch_async(dispatch_get_main_queue(), ^{
            UIViewController *viewController = NXTopViewController(NXWindowServer.shared.rootViewController);
            UIAlertController *alertController = [UIAlertController alertControllerWithTitle:NXStringForNXAlertDiagnosticPresenterLevel(level) message:message preferredStyle:UIAlertControllerStyleAlert];
            [alertController addAction:[UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleCancel handler:nil]];
            [viewController presentViewController:alertController animated:YES completion:nil];
        });
    });
}

@end
