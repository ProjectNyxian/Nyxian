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

#ifndef NXWINDOWBAR_H
#define NXWINDOWBAR_H

#import <UIKit/UIKit.h>

@interface NXWindowBar : UIView

@property (nonatomic, strong, readonly) UIVisualEffectView *buttonIsland;

@property (nonatomic,strong) UIButton *closeButton;
@property (nonatomic,strong) UIButton *maximizeButton;
@property (nonatomic,strong,getter=getTitle,setter=setTitle:) NSString *title;

- (instancetype)initWithTitle:(NSString*)title withCloseCallback:(void (^)(void))closeCallback withMaximizeCallback:(void (^)(void))maximizeCallback;
- (void)changeFocus:(BOOL)focusState;

- (void)setFullscreen:(BOOL)fullscreen animated:(BOOL)animated;

@end

#endif /* NXWINDOWBAR_H */
