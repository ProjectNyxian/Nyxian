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

#ifndef LDEWINDOWSESSIONAPPLICATION_H
#define LDEWINDOWSESSIONAPPLICATION_H

#import <LindChain/Multitask/ProcessManager/LDEProcessManager.h>
#import <LindChain/Multitask/WindowServer/LDEWindowSession.h>
#import <LindChain/Private/UIKitPrivate.h>

@interface LDEWindowSessionApplication : UIViewController <LDEWindowSession,_UISceneSettingsDiffAction>

@property (nonatomic) UIView* contentView;
@property (nonatomic, weak) LDEProcess *process;
@property (nonatomic) _UIScenePresenter *presenter;
@property (nonatomic, strong) NSTimer *backgroundEnforcementTimer;
@property (nonatomic) CGRect windowSize;

- (instancetype)initWithProcess:(LDEProcess*)process;

@end

void LDEBringApplicationSessionToFrontAssosiatedWithBundleIdentifier(NSString *bundleIdentifier);

#endif /* LDEWINDOWSESSIONAPPLICATION_H */
