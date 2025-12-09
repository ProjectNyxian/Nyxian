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

#ifndef LDEWINDOWSERVER_H
#define LDEWINDOWSERVER_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <Project/NXProject.h>
#import <LindChain/Multitask/WindowServer/LDEWindow.h>
#import <LindChain/Multitask/WindowServer/LaunchPad/LDEAppLaunchpad.h>

@interface LDEWindowServer : UIWindow <UIGestureRecognizerDelegate,LDEWindowDelegate,LDEAppLaunchpadDelegate>

@property (nonatomic,strong,readonly) NSMutableDictionary<NSNumber*,LDEWindow*> *windows;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *windowOrder;

@property (nonatomic, strong) UIView *appSwitcherView;
@property (nonatomic, strong) NSLayoutConstraint *appSwitcherTopConstraint;
@property (nonatomic, strong) UIImpactFeedbackGenerator *impactGenerator;

- (instancetype)initWithWindowScene:(UIWindowScene *)windowScene;
+ (instancetype)sharedWithWindowScene:(UIWindowScene*)windowScene;
+ (instancetype)shared;

- (BOOL)closeWindowWithIdentifier:(wid_t)identifier;
- (BOOL)openWindowWithSession:(UIViewController<LDEWindowSession>*)session identifier:(wid_t*)identifier;
- (void)activateWindowForIdentifier:(wid_t)identifier animated:(BOOL)animated withCompletion:(void (^)(void))completion;
- (void)focusWindowForIdentifier:(wid_t)identifier;
- (void)showAppSwitcherExternal;
- (LDEAppLaunchpad *)getOrCreateLaunchpad;

@end

#endif /* LDEWINDOWSERVER_H */

