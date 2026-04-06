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

#import <LindChain/WindowServer/NXAppTile.h>

@implementation NXAppTile

- (instancetype)initWithWindow:(NXWindow*)window
{
    self = [super init];
    self.nxWindow = window;
    [self setupView];
    [self update];  /* MARK: will later be used instead of setupView to setup a tile */
    return self;
}

- (void)setupView
{
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.clipsToBounds = NO;
    
    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = _nxWindow.windowName ?: @"App";
    title.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    title.textAlignment = NSTextAlignmentCenter;
    _titleLabel = title;
    
    UIView *tileWrapper = [[UIView alloc] init];
    tileWrapper.translatesAutoresizingMaskIntoConstraints = NO;
    tileWrapper.clipsToBounds = NO;
    tileWrapper.userInteractionEnabled = YES;
    _tileWrapper = tileWrapper;
    
    UIVisualEffectView *tileMaterial = [self createTileMaterial];
    tileMaterial.translatesAutoresizingMaskIntoConstraints = NO;
    
    UIImageView *tile = [[UIImageView alloc] init];
    UIImage *snapshot = [_nxWindow.session snapshotWindow];
    if(snapshot != nil)
    {
        tile.image = snapshot;
    }
    tile.clipsToBounds = YES;
    tile.translatesAutoresizingMaskIntoConstraints = NO;
    tile.contentMode = UIViewContentModeScaleAspectFill;
    tile.layer.cornerRadius = 14;
    tile.alpha = 0.92;
    
    UIView *shineView = [self createShineView];
    
    [self applyTileShadowEffects:tileWrapper tileMaterial:tileMaterial];
    
    UIImageView *reflection = [self createReflectionWithSnapshot:snapshot];
    
    [tileMaterial.contentView addSubview:tile];
    [tileMaterial.contentView addSubview:shineView];
    [tileWrapper addSubview:tileMaterial];
    [self addSubview:reflection];
    [self addSubview:tileWrapper];
    [self addSubview:title];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.widthAnchor constraintEqualToConstant:150],
        [self.heightAnchor constraintEqualToConstant:380],
        
        [title.topAnchor constraintEqualToAnchor:self.topAnchor],
        [title.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [title.widthAnchor constraintEqualToConstant:140],
        
        [tileWrapper.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:8],
        [tileWrapper.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [tileWrapper.widthAnchor constraintEqualToConstant:150],
        [tileWrapper.heightAnchor constraintEqualToConstant:280],
        
        [tileMaterial.topAnchor constraintEqualToAnchor:tileWrapper.topAnchor],
        [tileMaterial.leadingAnchor constraintEqualToAnchor:tileWrapper.leadingAnchor],
        [tileMaterial.trailingAnchor constraintEqualToAnchor:tileWrapper.trailingAnchor],
        [tileMaterial.bottomAnchor constraintEqualToAnchor:tileWrapper.bottomAnchor],
        
        [tile.topAnchor constraintEqualToAnchor:tileMaterial.contentView.topAnchor constant:2],
        [tile.leadingAnchor constraintEqualToAnchor:tileMaterial.contentView.leadingAnchor constant:2],
        [tile.trailingAnchor constraintEqualToAnchor:tileMaterial.contentView.trailingAnchor constant:-2],
        [tile.bottomAnchor constraintEqualToAnchor:tileMaterial.contentView.bottomAnchor constant:-2],
        
        [shineView.topAnchor constraintEqualToAnchor:tile.topAnchor],
        [shineView.leadingAnchor constraintEqualToAnchor:tile.leadingAnchor],
        [shineView.trailingAnchor constraintEqualToAnchor:tile.trailingAnchor],
        [shineView.bottomAnchor constraintEqualToAnchor:tile.bottomAnchor],
        
        [reflection.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [reflection.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [reflection.widthAnchor constraintEqualToConstant:150],
        [reflection.heightAnchor constraintEqualToConstant:60]
    ]];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        CAGradientLayer *shineGradient = (CAGradientLayer *)shineView.layer.sublayers.firstObject;
        shineGradient.frame = shineView.bounds;
        
        CAGradientLayer *gradientMask = [CAGradientLayer layer];
        gradientMask.frame = CGRectMake(0, 0, 150, 60);
        gradientMask.colors = @[
            (id)[UIColor whiteColor].CGColor,
            (id)[UIColor clearColor].CGColor
        ];
        gradientMask.startPoint = CGPointMake(0.5, 0);
        gradientMask.endPoint = CGPointMake(0.5, 1);
        reflection.layer.mask = gradientMask;
    });
}

- (UIVisualEffectView *)createTileMaterial
{
    UIVisualEffectView *tileMaterial;
    if(@available(iOS 26.0, *))
    {
        UIGlassEffect *glass = [[UIGlassEffect alloc] init];
        tileMaterial = [[UIVisualEffectView alloc] initWithEffect:glass];
    }
    else
    {
        UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThinMaterial];
        tileMaterial = [[UIVisualEffectView alloc] initWithEffect:blur];
    }
    tileMaterial.layer.cornerRadius = 16;
    tileMaterial.layer.masksToBounds = YES;
    _tileMaterial = tileMaterial;
    return tileMaterial;
}

- (UIView *)createShineView
{
    UIView *shineView = [[UIView alloc] init];
    shineView.translatesAutoresizingMaskIntoConstraints = NO;
    shineView.userInteractionEnabled = NO;
    shineView.layer.cornerRadius = 14;
    shineView.clipsToBounds = YES;
    
    CAGradientLayer *shineGradient = [CAGradientLayer layer];
    shineGradient.colors = @[
        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.08].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.10].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.04].CGColor,
        (id)[UIColor colorWithWhite:1.0 alpha:0.0].CGColor
    ];
    shineGradient.locations = @[@0.0, @0.3, @0.45, @0.7, @1.0];
    shineGradient.startPoint = CGPointMake(0, 0);
    shineGradient.endPoint = CGPointMake(1, 1);
    [shineView.layer insertSublayer:shineGradient atIndex:0];
    
    return shineView;
}

- (void)applyTileShadowEffects:(UIView *)tileWrapper tileMaterial:(UIVisualEffectView *)tileMaterial
{
    tileWrapper.layer.shadowColor = [UIColor colorWithWhite:1.0 alpha:0.8].CGColor;
    tileWrapper.layer.shadowOpacity = 0.15;
    tileWrapper.layer.shadowRadius = 8;
    tileWrapper.layer.shadowOffset = CGSizeZero;
    
    tileMaterial.layer.shadowColor = [UIColor blackColor].CGColor;
    tileMaterial.layer.shadowOpacity = 0.25;
    tileMaterial.layer.shadowRadius = 12;
    tileMaterial.layer.shadowOffset = CGSizeMake(0, 6);
}

- (UIImageView *)createReflectionWithSnapshot:(UIImage *)snapshot
{
    UIImageView *reflection = [[UIImageView alloc] init];
    if(snapshot != nil)
    {
        reflection.image = snapshot;
    }
    reflection.translatesAutoresizingMaskIntoConstraints = NO;
    reflection.contentMode = UIViewContentModeScaleAspectFill;
    reflection.clipsToBounds = YES;
    reflection.layer.cornerRadius = 16;
    reflection.transform = CGAffineTransformMakeScale(1, -1);
    reflection.alpha = 0.35;
    _reflection = reflection;
    return reflection;
}

- (void)update
{
    /* TODO: this symbol will later be used to update all information presented to the user by this tile */
    return;
}

@end
