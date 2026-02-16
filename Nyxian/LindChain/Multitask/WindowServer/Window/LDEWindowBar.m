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

#import <LindChain/Multitask/WindowServer/Window/LDEWindowBar.h>

@implementation LDEWindowBar {
    UIView *_bottomBorder;
}

- (instancetype)initWithTitle:(NSString*)title
            withCloseCallback:(void (^)(void))closeCallback
         withMaximizeCallback:(void (^)(void))maximizeCallback
{
    self = [super init];
    if (!self) return nil;

    self.translatesAutoresizingMaskIntoConstraints = NO;

    UIBlurEffect *blur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
    UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blur];
    blurView.translatesAutoresizingMaskIntoConstraints = NO;
    [self addSubview:blurView];

    [NSLayoutConstraint activateConstraints:@[
        [blurView.topAnchor constraintEqualToAnchor:self.topAnchor],
        [blurView.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
        [blurView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [blurView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
    ]];

    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = title;
    titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
    titleLabel.textAlignment = NSTextAlignmentCenter;
    titleLabel.font = [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    [self addSubview:titleLabel];

    UIButtonConfiguration *closeConfig = [UIButtonConfiguration plainButtonConfiguration];
    closeConfig.preferredSymbolConfigurationForImage = [UIImageSymbolConfiguration configurationWithPointSize:17
                                                        weight:UIImageSymbolWeightSemibold];
    closeConfig.image = [UIImage systemImageNamed:@"xmark.circle.fill"];

    UIButton *closeButton = [UIButton buttonWithConfiguration:closeConfig primaryAction:nil];
    closeButton.translatesAutoresizingMaskIntoConstraints = NO;
    if(closeCallback)
    {
        [closeButton addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
            closeCallback();
        }] forControlEvents:UIControlEventTouchUpInside];
    }
    _closeButton = closeButton;

    if(UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad)
    {
        UIButtonConfiguration *maxConfig = [UIButtonConfiguration plainButtonConfiguration];
        maxConfig.preferredSymbolConfigurationForImage =
        [UIImageSymbolConfiguration configurationWithPointSize:17
                                                        weight:UIImageSymbolWeightSemibold];
        maxConfig.image = [UIImage systemImageNamed:@"arrow.up.left.and.arrow.down.right.circle.fill"];
        
        UIButton *maximizeButton = [UIButton buttonWithConfiguration:maxConfig primaryAction:nil];
        maximizeButton.translatesAutoresizingMaskIntoConstraints = NO;
        if(maximizeCallback)
        {
            [maximizeButton addAction:[UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
                maximizeCallback();
            }] forControlEvents:UIControlEventTouchUpInside];
        }
        _maximizeButton = maximizeButton;
        
        UIStackView *buttonStack = [[UIStackView alloc] initWithArrangedSubviews:@[
            closeButton,
            maximizeButton
        ]];
        buttonStack.axis = UILayoutConstraintAxisHorizontal;
        buttonStack.spacing = 6;
        buttonStack.translatesAutoresizingMaskIntoConstraints = NO;
        
        [self addSubview:buttonStack];
        
        [NSLayoutConstraint activateConstraints:@[
            [buttonStack.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
            [buttonStack.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:12],
            [closeButton.widthAnchor constraintEqualToConstant:30],
            [closeButton.heightAnchor constraintEqualToConstant:30],
            [maximizeButton.widthAnchor constraintEqualToConstant:30],
            [maximizeButton.heightAnchor constraintEqualToConstant:30],
        ]];
    }

    UIView *bottomBorder = [[UIView alloc] init];
    bottomBorder.translatesAutoresizingMaskIntoConstraints = NO;
    bottomBorder.backgroundColor = UIColor.systemGray3Color;
    [self addSubview:bottomBorder];
    _bottomBorder = bottomBorder;
    
    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [titleLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.heightAnchor constraintEqualToConstant:50],
        [bottomBorder.heightAnchor constraintEqualToConstant:0.5],
        [bottomBorder.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [bottomBorder.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [bottomBorder.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    ]];

    return self;
}

- (void)dealloc
{
    NSLog(@"deallocated %@", self);
}

@end

