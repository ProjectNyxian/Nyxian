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

#ifndef LDEWINDOWSESSION_H
#define LDEWINDOWSESSION_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

typedef int wid_t;

@interface LDEWindowSession : UIViewController

@property (nonatomic,weak) UIWindowScene *windowScene;
@property (nonatomic) wid_t windowIdentifier;

@property (nonatomic) CGRect windowRect;

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
- (NSString*)windowName;

- (void)movedWindowToScene:(UIWindowScene*)windowScene withIdentifier:(wid_t)identifier;

@end

#endif /* LDEWINDOWSESSION_H */

