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

#import <UIKit/UIKit.h>
#import <NXSceneDelegate.h>
#import <LindChain/WindowServer/NXWindowServer.h>
#import <Nyxian-Swift.h>

#if JAILBREAK_ENV
#import <LindChain/JBSupport/Shell.h>
#else
#import <bridge.h>
#endif /* JAILBREAK_ENV */

@implementation NXSceneDelegate {
    NXWindowServer *_window;
    UIViewController *_fakeViewController;
}

- (void)scene:(UIScene *)scene willConnectToSession:(UISceneSession *)session options:(UISceneConnectionOptions *)connectionOptions
{
    if(scene == nil || ![scene isKindOfClass:[UIWindowScene class]])
    {
        return;
    }
    UIWindowScene *windowScene = (UIWindowScene*)scene;
    
    _window = [NXWindowServer sharedWithWindowScene:windowScene];
    if(_window == nil)
    {
        return;
    }
    
#if JAILBREAK_ENV
    int ret = shell(@[[[NSBundle mainBundle] executablePath]], 0, nil, nil);
    if(ret != 0)
    {
        UILabel *label = [[UILabel alloc] init];
        label.text = [NSString stringWithFormat:@"NyxianForJB is incorrectly entitled\n\n\ntest exec ret: %d", ret];
        label.frame = UIScreen.mainScreen.bounds;
        label.numberOfLines = 0;
        label.textAlignment = NSTextAlignmentCenter;
        [_window addSubview:label];
        [_window makeKeyAndVisible];
        [_window bringSubviewToFront:label];
        return;
    }
#else
    if(!liveProcessIsAvailable())
    {
        UILabel *label = [[UILabel alloc] init];
        label.text = [NSString stringWithFormat:@"NSExtension missing, make sure you keep the extension when installing."];
        label.frame = UIScreen.mainScreen.bounds;
        label.numberOfLines = 0;
        label.textAlignment = NSTextAlignmentCenter;
        [_window addSubview:label];
        [_window makeKeyAndVisible];
        [_window bringSubviewToFront:label];
        return;
    }
#endif /* JAILBREAK_ENV */
    
    [[Bootstrap shared] bootstrap];
    
    UIThemedTabViewController *themedTabViewController = [[UIThemedTabViewController alloc] init];
    
    ContentViewController *contentViewController = [[ContentViewController alloc] initWithPath: [[Bootstrap shared] bootstrapPath:@"/Projects"]];
    SettingsViewController *settingsViewController = [[SettingsViewController alloc] initWithStyle:UITableViewStyleInsetGrouped];
    
    UINavigationController *contentNavigationController = [[UINavigationController alloc] initWithRootViewController:contentViewController];
    UINavigationController *settingsNavigationController = [[UINavigationController alloc] initWithRootViewController:settingsViewController];
    
    contentNavigationController.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Projects" image:[UIImage systemImageNamed:@"folder.fill"] tag:0];
    settingsNavigationController.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Settings" image:[UIImage systemImageNamed:@"gear"] tag:2];
    
#if !JAILBREAK_ENV
    ApplicationManagementViewController * applicationViewController = [ApplicationManagementViewController shared];
    UINavigationController *applicationNavigationController = [[UINavigationController alloc] initWithRootViewController:applicationViewController];
    applicationViewController.tabBarItem = [[UITabBarItem alloc] initWithTitle:@"Applications" image:[UIImage systemImageNamed:@"square.grid.2x2.fill"] tag:1];
    NSMutableArray<UIViewController*> *viewControllers = [[NSMutableArray alloc] initWithArray:@[contentNavigationController, applicationNavigationController, settingsNavigationController]];
#else
    NSMutableArray<UIViewController*> *viewControllers = [[NSMutableArray alloc] initWithArray:@[contentNavigationController, settingsNavigationController]];
#endif /* !JAILBREAK_ENV */
    
    if(@available(iOS 26.0, *))
    {
        if(UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone)
        {
            _fakeViewController = [[UIViewController alloc] init];
            _fakeViewController.tabBarItem = [[UITabBarItem alloc] initWithTabBarSystemItem:UITabBarSystemItemSearch tag:viewControllers.count];
            _fakeViewController.tabBarItem.title = @"Switcher";
            _fakeViewController.tabBarItem.image = [UIImage systemImageNamed:@"iphone.app.switcher"];
            [viewControllers addObject:_fakeViewController];
        }
    }
    
    themedTabViewController.viewControllers = viewControllers;
    themedTabViewController.delegate = self;
    
    _window.rootViewController = themedTabViewController;
    [_window makeKeyAndVisible];
}

- (BOOL)tabBarController:(UITabBarController *)tabBarController shouldSelectViewController:(UIViewController *)viewController
{
    if(viewController.tabBarItem.tag == _fakeViewController.tabBarItem.tag)
    {
        [_window showAppSwitcherExternal];
        return NO;
    }
    return YES;
}

@end
