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

#import <LindChain/WindowServer/Window/NXWindowSession.h>
#import <LindChain/WindowServer/Window/NXWindow.h>

@implementation NXWindowSession

- (instancetype)init
{
    self = [super init];
    if(self)
    {
        _startWindowRect = CGRectMake(50, 50, 375, 667);
    }
    return self;
}

- (BOOL)openWindow
{
    return YES;
}

- (BOOL)closeWindow
{
    return YES;
}

- (BOOL)needRatioLocked
{
    return NO;
}

- (BOOL)activateWindow
{
    return YES;
}

- (BOOL)deactivateWindow
{
    return YES;
}

- (BOOL)focusWindow
{
    return YES;
}

- (BOOL)unfocusWindow
{
    return YES;
}

- (UIImage*)snapshotWindow
{
    UIGraphicsBeginImageContextWithOptions(self.view.bounds.size, NO, 0.0);
    CGContextRef context = UIGraphicsGetCurrentContext();
    [self.view.layer renderInContext:context];
    UIImage *snapshot = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return snapshot;
}

- (NSString*)getWindowName
{
    __strong NXWindow *window = self.window;
    return (window == nil) ? window.windowName : @"Unknown";
}

- (void)setWindowName:(NSString *)windowName
{
    __strong NXWindow *window = self.window;
    if(window != nil)
    {
        window.windowName = windowName;
    }
}

- (void)windowBeganResizing
{
    return;
}

- (void)windowEndedResizing
{
    return;
}

- (void)windowDidMove
{
    return;
}

@end
