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

#import <LindChain/Multitask/WindowServer/LaunchPad/LDEAppCell.h>

@implementation LDEAppCell

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if(self)
    {
        [self setupCell];
    }
    return self;
}

- (void)setupCell
{
    _glowView = [[UIView alloc] init];
    _glowView.translatesAutoresizingMaskIntoConstraints = NO;
    _glowView.backgroundColor = [UIColor clearColor];
    _glowView.layer.shadowColor = [UIColor systemBlueColor].CGColor;
    _glowView.layer.shadowOpacity = 0;
    _glowView.layer.shadowRadius = 15;
    _glowView.layer.shadowOffset = CGSizeZero;
    [self.contentView addSubview:_glowView];
    
    UIView *iconBackground = [[UIView alloc] init];
    iconBackground.translatesAutoresizingMaskIntoConstraints = NO;
    iconBackground.backgroundColor = [UIColor clearColor];
    [self.contentView addSubview:iconBackground];
    
    _iconView = [[UIImageView alloc] init];
    _iconView.translatesAutoresizingMaskIntoConstraints = NO;
    _iconView.contentMode = UIViewContentModeScaleAspectFill;
    _iconView.clipsToBounds = YES;
    _iconView.layer.borderWidth = 0.5;
    _iconView.layer.borderColor = [UIColor grayColor].CGColor;
    
    if(@available(iOS 26.0, *))
    {
        _iconView.layer.cornerRadius = 15;
    }
    else
    {
        _iconView.layer.cornerRadius = 12;
    }
    
    [iconBackground addSubview:_iconView];
    
    _nameLabel = [[UILabel alloc] init];
    _nameLabel.translatesAutoresizingMaskIntoConstraints = NO;
    _nameLabel.font = [UIFont systemFontOfSize:11 weight:UIFontWeightMedium];
    _nameLabel.textColor = [UIColor labelColor];
    _nameLabel.textAlignment = NSTextAlignmentCenter;
    _nameLabel.numberOfLines = 2;
    _nameLabel.lineBreakMode = NSLineBreakByTruncatingTail;
    [self.contentView addSubview:_nameLabel];
    
    CGFloat iconSize = 54;
    
    [NSLayoutConstraint activateConstraints:@[
        [_glowView.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [_glowView.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:3],
        [_glowView.widthAnchor constraintEqualToConstant:iconSize],
        [_glowView.heightAnchor constraintEqualToConstant:iconSize],
        
        [iconBackground.centerXAnchor constraintEqualToAnchor:self.contentView.centerXAnchor],
        [iconBackground.topAnchor constraintEqualToAnchor:self.contentView.topAnchor constant:3],
        [iconBackground.widthAnchor constraintEqualToConstant:iconSize],
        [iconBackground.heightAnchor constraintEqualToConstant:iconSize],

        [_iconView.widthAnchor constraintEqualToConstant:iconSize],
        [_iconView.heightAnchor constraintEqualToConstant:iconSize],
        [_iconView.centerXAnchor constraintEqualToAnchor:iconBackground.centerXAnchor],
        [_iconView.centerYAnchor constraintEqualToAnchor:iconBackground.centerYAnchor],
        
        [_nameLabel.topAnchor constraintEqualToAnchor:iconBackground.bottomAnchor constant:5],
        [_nameLabel.leadingAnchor constraintEqualToAnchor:self.contentView.leadingAnchor],
        [_nameLabel.trailingAnchor constraintEqualToAnchor:self.contentView.trailingAnchor],
    ]];
    
    _iconContainer = nil;
}

- (void)setHighlighted:(BOOL)highlighted
{
    [super setHighlighted:highlighted];
    
    [UIView animateWithDuration:0.15 animations:^{
        if (highlighted) {
            self.iconView.transform = CGAffineTransformMakeScale(0.9, 0.9);
            self.glowView.layer.shadowOpacity = 0.6;
        } else {
            self.iconView.transform = CGAffineTransformIdentity;
            self.glowView.layer.shadowOpacity = 0;
        }
    }];
}

- (void)prepareForReuse
{
    [super prepareForReuse];
    self.iconView.image = nil;
    self.nameLabel.text = nil;
    self.iconView.transform = CGAffineTransformIdentity;
    self.glowView.layer.shadowOpacity = 0;
}

@end
