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

#import <UI/UIInit/NXUISwitch.h>
#import <Nyxian-Swift.h>

@implementation NXUISwitch

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if(self)
    {
        [self setup];
    }
    return self;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if(self)
    {
        [self setup];
    }
    return self;
}

- (void)setup
{
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(handleRethemeNotification:) name:@"uiColorChangeNotif" object:nil];
    [self applyTheme];
    __weak __typeof(self) weakSelf = self;
    [self registerForTraitChanges:@[UITraitUserInterfaceStyle.class] withHandler:^(id<UITraitEnvironment> traitEnvironment, UITraitCollection *previousCollection) {
        [weakSelf applyTheme];
    }];
}

- (void)handleRethemeNotification:(NSNotification*)notification
{
    [self applyTheme];
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    [self applyTheme];
}

- (void)applyTheme
{
    self.onTintColor = LDETheme.currentTheme.appLabel;
    self.thumbTintColor = LDETheme.currentTheme.appTableCell;
}

- (void)dealloc
{
    [NSNotificationCenter.defaultCenter removeObserver:self];
}

@end
