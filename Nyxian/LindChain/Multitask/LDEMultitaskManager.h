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
#import <Project/NXProject.h>
#import <LindChain/Multitask/LDEWindow.h>

@interface LDEMultitaskManager : UIWindow <UIGestureRecognizerDelegate>

@property (nonatomic,strong,readonly) NSMutableDictionary<NSNumber*,LDEWindow*> *windows;

@property (nonatomic, strong) UIView *appSwitcherView;
@property (nonatomic, strong) NSLayoutConstraint *appSwitcherTopConstraint;
@property (nonatomic, strong) UIImpactFeedbackGenerator *impactGenerator;

- (instancetype)init;
+ (instancetype)shared;

- (BOOL)openWindowForProcessIdentifier:(pid_t)processIdentifier;
- (BOOL)closeWindowForProcessIdentifier:(pid_t)processIdentifier;

@end
