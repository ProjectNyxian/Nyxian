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

#ifndef NXWINDOW_H
#define NXWINDOW_H

#import <LindChain/Private/FoundationPrivate.h>
#import <LindChain/WindowServer/Window/NXWindowSession.h>

@class NXWindow;

@protocol NXWindowDelegate <NSObject>

@property (nonatomic) UIWindowScene *windowScene;

- (void)windowWantsToClose:(NXWindow*)window;
- (void)windowWantsToFocus:(NXWindow*)window;
- (void)windowWantsToMinimize:(NXWindow*)window;

- (CGRect)window:(NXWindow*)window wantsToChangeToRect:(CGRect)rect;

@end

@interface NXWindow : UIViewController <UIGestureRecognizerDelegate>

@property (nonatomic) id_t identifier;
@property (nonatomic,getter=getWindowName,setter=setWindowName:) NSString* windowName;
@property (nonatomic) BOOL isMaximized;
@property (nonatomic) CGRect originalFrame;
@property (nonatomic) NXWindowSession *session;
@property (nonatomic, weak) id<NXWindowDelegate> delegate;

- (instancetype)initWithSession:(NXWindowSession*)session withDelegate:(id<NXWindowDelegate>)delegate;

- (void)openWindow;
- (void)closeWindowWithCompletion:(void (^)(BOOL))completion;
- (void)unfocusWindow;
- (void)focusWindow;

- (void)maximizeWindow:(BOOL)animated;
- (void)changeWindowToRect:(CGRect)rect completion:(void (^)(BOOL))completion;

- (void)deinit;

@end

#endif /* NXWINDOW_H */
