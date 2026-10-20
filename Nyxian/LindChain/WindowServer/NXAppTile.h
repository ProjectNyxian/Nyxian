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

#ifndef NXAPPTILE_H
#define NXAPPTILE_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <LindChain/WindowServer/Window/NXWindow.h>

@interface NXAppTile : UIView

@property (nonatomic,weak) NXWindow *nxWindow;

@property (nonatomic, weak) UIView *tileWrapper;
@property (nonatomic, weak) UIVisualEffectView *tileMaterial;
@property (nonatomic, weak) UILabel *titleLabel;
@property (nonatomic, weak) UIImageView *reflection;

- (instancetype)initWithWindow:(NXWindow*)window;
- (void)update;

@end

#endif /* NXAPPTILE_H */
