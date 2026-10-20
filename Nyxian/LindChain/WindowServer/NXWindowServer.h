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

#ifndef NXWINDOWSERVER_H
#define NXWINDOWSERVER_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <LindChain/WindowServer/Window/NXWindow.h>

typedef UInt64 NXWindowServerPresentationState NS_TYPED_ENUM;
static NXWindowServerPresentationState const NXWindowServerPresentationStateDefault = 0;
static NXWindowServerPresentationState const NXWindowServerPresentationStateFullScreen = 1;
static NXWindowServerPresentationState const NXWindowServerPresentationStateOutOfMyWay = 2;

@interface NXWindowServer : UIWindow <UIGestureRecognizerDelegate,NXWindowDelegate>

@property (nonatomic, readonly) NXWindowServerPresentationState presentationState;
@property (nonatomic, weak, readonly) NXWindow *fullScreenWindow;

@property (nonatomic, strong,readonly) NSMutableDictionary<NSNumber*,NXWindow*> *windows;
@property (nonatomic, strong) NSMutableArray<NSNumber *> *windowOrder;

@property (nonatomic, strong) UIView *appSwitcherView;
@property (nonatomic, strong) NSLayoutConstraint *appSwitcherTopConstraint;
@property (nonatomic, strong) UIImpactFeedbackGenerator *impactGenerator;

- (instancetype)initWithWindowScene:(UIWindowScene *)windowScene;
+ (instancetype)sharedWithWindowScene:(UIWindowScene*)windowScene;
+ (instancetype)shared;

- (void)openWindowWithSession:(NXWindowSession*)session withCompletion:(void (^)(BOOL))completion;
- (void)closeWindowWithIdentifier:(id_t)identifier  withCompletion:(void (^)(BOOL))completion;

- (void)activateWindowForIdentifier:(id_t)identifier animated:(BOOL)animated withCompletion:(void (^)(void))completion;

- (void)focusWindowForIdentifier:(id_t)identifier;
- (NXWindowSession*)windowSessionForIdentifier:(id_t)identifier;
- (NXWindowSession*)windowSessionForBundleIdentifier:(NSString*)bundleIdentifier;
- (id_t)windowIdentifierForBundleIdentifier:(NSString*)bundleIdentifier;
- (void)unfocusFocusedWindow;
- (void)windowsGetOutOfMyWay;
- (void)windowsGetInMyWay;

- (void)showAppSwitcherExternal;

@end

#endif /* NXWINDOWSERVER_H */

