/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 mach-port-t

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

#ifndef NXWINDOWSESSION_H
#define NXWINDOWSESSION_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class NXWindow;

@interface NXWindowSession : UIViewController

@property (nonatomic,weak) UIWindowScene *windowScene;
@property (nonatomic,weak) NXWindow *window;
@property (nonatomic) id_t windowIdentifier;

@property (nonatomic) CGRect windowRect;
@property (nonatomic,strong,getter=getWindowName,setter=setWindowName:) NSString *windowName;

@property (nonatomic) BOOL isFullscreen;
@property (nonatomic) BOOL isActive;
@property (nonatomic) BOOL isFocused;

- (BOOL)openWindow;
- (BOOL)closeWindow;

- (BOOL)activateWindow;
- (BOOL)deactivateWindow;

- (BOOL)focusWindow;
- (BOOL)unfocusWindow;

- (void)windowChangesToRect:(CGRect)rect;

- (UIImage*)snapshotWindow;

- (void)movedWindowToScene:(UIWindowScene*)windowScene withIdentifier:(id_t)identifier;

@end

#endif /* NXWINDOWSESSION_H */

