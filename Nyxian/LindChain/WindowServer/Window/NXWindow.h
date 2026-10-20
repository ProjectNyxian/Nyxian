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

#ifndef NXWINDOW_H
#define NXWINDOW_H

#import <LindChain/Private/FoundationPrivate.h>
#import <LindChain/WindowServer/Window/NXWindowSession.h>

@class NXWindow;

@protocol NXWindowDelegate <NSObject>

@property (nonatomic) UIWindowScene *windowScene;

- (void)windowWantsToClose:(NXWindow*)window;
- (BOOL)windowWantsToFocus:(NXWindow*)window;
- (void)windowWantsToMinimize:(NXWindow*)window;
- (void)windowWantsToMaximize:(NXWindow*)window;

- (CGRect)window:(NXWindow*)window wantsToChangeToRect:(CGRect)rect;

@end

@interface NXWindow : UIViewController <UIGestureRecognizerDelegate>

@property (nonatomic) id_t identifier;
@property (nonatomic,getter=getWindowName,setter=setWindowName:) NSString* windowName;
@property (nonatomic) BOOL isMaximized;
@property (nonatomic) CGRect originalFrame;
@property (nonatomic) NXWindowSession *session;
@property (nonatomic, weak) id<NXWindowDelegate> delegate;
@property (nonatomic) CGRect lastValidFrame;
@property (nonatomic) CGFloat lockedAspect;
@property (nonatomic) BOOL ratioLocked;

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
