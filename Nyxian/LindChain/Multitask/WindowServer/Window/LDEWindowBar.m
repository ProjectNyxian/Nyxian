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

    UIView *_dotContainer;
    UIStackView *_buttonStack;

    NSLayoutConstraint *_islandWidthConstraint;
    NSLayoutConstraint *_islandHeightConstraint;

    BOOL _islandExpanded;
    NSTimer *_collapseTimer;
}

- (instancetype)initWithTitle:(NSString *)title
            withCloseCallback:(void (^)(void))closeCallback
         withMaximizeCallback:(void (^)(void))maximizeCallback
{
    self = [super init];
    if (!self) return nil;

    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.clipsToBounds = NO;

    BOOL isiPad  = (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPad);
    CGFloat barH = isiPad ? 38.0 : 50.0;

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
    titleLabel.font = [UIFont systemFontOfSize:isiPad ? 13 : 17 weight:UIFontWeightSemibold];
    [self addSubview:titleLabel];

    UIView *border = [[UIView alloc] init];
    border.translatesAutoresizingMaskIntoConstraints = NO;
    border.backgroundColor = UIColor.systemGray3Color;
    [self addSubview:border];
    _bottomBorder = border;

    [NSLayoutConstraint activateConstraints:@[
        [titleLabel.centerXAnchor constraintEqualToAnchor:self.centerXAnchor],
        [titleLabel.centerYAnchor constraintEqualToAnchor:self.centerYAnchor],
        [self.heightAnchor constraintEqualToConstant:barH],
        [border.heightAnchor constraintEqualToConstant:0.5],
        [border.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
        [border.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
        [border.bottomAnchor constraintEqualToAnchor:self.bottomAnchor],
    ]];

    if(isiPad)
    {
        _islandExpanded = NO;

        UIView *island = [[UIView alloc] init];
        island.translatesAutoresizingMaskIntoConstraints = NO;
        island.clipsToBounds = YES;
        island.layer.cornerRadius = 26.0 / 2.0;
        island.layer.cornerCurve = kCACornerCurveContinuous;

        UIBlurEffect *islandBlur = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemUltraThinMaterial];
        UIVisualEffectView *bg = [[UIVisualEffectView alloc] initWithEffect:islandBlur];
        bg.translatesAutoresizingMaskIntoConstraints = NO;
        [island addSubview:bg];
        [NSLayoutConstraint activateConstraints:@[
            [bg.topAnchor constraintEqualToAnchor:island.topAnchor],
            [bg.bottomAnchor constraintEqualToAnchor:island.bottomAnchor],
            [bg.leadingAnchor constraintEqualToAnchor:island.leadingAnchor],
            [bg.trailingAnchor constraintEqualToAnchor:island.trailingAnchor],
        ]];

        [self addSubview:island];
        _buttonIsland = island;

        UIView *dotContainer = [[UIView alloc] init];
        dotContainer.translatesAutoresizingMaskIntoConstraints = NO;
        [island addSubview:dotContainer];
        _dotContainer = dotContainer;

        UIView *closeDot = [self _dotWithColor:UIColor.systemRedColor];
        UIView *maxDot   = [self _dotWithColor:UIColor.systemGreenColor];
        [dotContainer addSubview:closeDot];
        [dotContainer addSubview:maxDot];

        [NSLayoutConstraint activateConstraints:@[
            [closeDot.leadingAnchor constraintEqualToAnchor:dotContainer.leadingAnchor],
            [closeDot.centerYAnchor constraintEqualToAnchor:dotContainer.centerYAnchor],
            [closeDot.widthAnchor constraintEqualToConstant:9.0],
            [closeDot.heightAnchor constraintEqualToConstant:9.0],
            [maxDot.leadingAnchor constraintEqualToAnchor:closeDot.trailingAnchor constant:6.0],
            [maxDot.trailingAnchor constraintEqualToAnchor:dotContainer.trailingAnchor],
            [maxDot.centerYAnchor constraintEqualToAnchor:dotContainer.centerYAnchor],
            [maxDot.widthAnchor constraintEqualToConstant:9.0],
            [maxDot.heightAnchor constraintEqualToConstant:9.0],
            [dotContainer.centerXAnchor constraintEqualToAnchor:island.centerXAnchor],
            [dotContainer.centerYAnchor constraintEqualToAnchor:island.centerYAnchor],
        ]];

        UIButton *closeBtn = [self _islandButtonWithImage:@"xmark.circle.fill" callback:closeCallback];
        UIButton *maxBtn = [self _islandButtonWithImage:@"arrow.up.left.and.arrow.down.right.circle.fill" callback:maximizeCallback];
        _closeButton = closeBtn;
        _maximizeButton = maxBtn;

        UIStackView *stack = [[UIStackView alloc] initWithArrangedSubviews:@[closeBtn, maxBtn]];
        stack.axis = UILayoutConstraintAxisHorizontal;
        stack.spacing = 8;
        stack.alignment = UIStackViewAlignmentCenter;
        stack.translatesAutoresizingMaskIntoConstraints = NO;
        stack.alpha = 0.0;
        stack.transform = CGAffineTransformMakeScale(0.5, 0.5);
        [island addSubview:stack];
        _buttonStack = stack;

        [NSLayoutConstraint activateConstraints:@[
            [stack.centerXAnchor  constraintEqualToAnchor:island.centerXAnchor],
            [stack.centerYAnchor  constraintEqualToAnchor:island.centerYAnchor],
            [closeBtn.widthAnchor  constraintEqualToConstant:30.0],
            [closeBtn.heightAnchor constraintEqualToConstant:30.0],
            [maxBtn.widthAnchor    constraintEqualToConstant:30.0],
            [maxBtn.heightAnchor   constraintEqualToConstant:30.0],
        ]];

        _islandWidthConstraint = [island.widthAnchor  constraintEqualToConstant:48.0];
        _islandHeightConstraint = [island.heightAnchor constraintEqualToConstant:26.0];
        [NSLayoutConstraint activateConstraints:@[
            [island.leadingAnchor constraintEqualToAnchor:self.leadingAnchor constant:10],
            _islandWidthConstraint,
            _islandHeightConstraint,
        ]];

        UILongPressGestureRecognizer *lp = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        lp.minimumPressDuration = 0.2;
        [island addGestureRecognizer:lp];
        
        UITapGestureRecognizer *bgTap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleBackgroundTap:)];
        bgTap.cancelsTouchesInView = NO;
        [self addGestureRecognizer:bgTap];
    }

    return self;
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)gr
{
    if(gr.state == UIGestureRecognizerStateBegan)
    {
        [self expandIsland];
    }
}

- (void)handleBackgroundTap:(UITapGestureRecognizer *)gr
{
    if(!_islandExpanded)
    {
        return;
    }
    
    CGPoint pt = [gr locationInView:self];
    BOOL insideIsland = [_buttonIsland pointInside:[self convertPoint:pt toView:_buttonIsland] withEvent:nil];
    
    if(!insideIsland)
    {
        [self collapseIsland];
    }
}

- (void)expandIsland
{
    if(_islandExpanded)
    {
        [self resetCollapseTimer];
        return;
    }
    _islandExpanded = YES;

    CGFloat newRadius = 58.0 / 2.0;
    
    UIView *layoutRoot = _buttonIsland.superview ?: self;

    [layoutRoot layoutIfNeeded];
    [UIView animateWithDuration:0.44 delay:0 usingSpringWithDamping:0.60 initialSpringVelocity:0.6 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        [self layoutIfNeeded];
        
        self->_buttonIsland.layer.cornerRadius = newRadius;
        self->_dotContainer.alpha     = 0.0;
        self->_dotContainer.transform = CGAffineTransformMakeScale(0.3, 0.3);
        self->_buttonStack.alpha     = 1.0;
        self->_buttonStack.transform = CGAffineTransformIdentity;
        
        self->_islandWidthConstraint.constant  = 120.0;
        self->_islandHeightConstraint.constant = 58.0;
        
        [layoutRoot layoutIfNeeded];
    } completion:nil];

    [self resetCollapseTimer];
}

- (void)collapseIsland
{
    if(!_islandExpanded)
    {
        return;
    }
    
    _islandExpanded = NO;

    [_collapseTimer invalidate];
    _collapseTimer = nil;

    CGFloat collapsedRadius = 26.0 / 2.0;
    
    UIView *layoutRoot = _buttonIsland.superview ?: self;

    [layoutRoot layoutIfNeeded];
    [UIView animateWithDuration:0.34 delay:0 usingSpringWithDamping:0.78 initialSpringVelocity:0.2 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
        [self layoutIfNeeded];
        
        self->_buttonIsland.layer.cornerRadius = collapsedRadius;
        self->_dotContainer.alpha     = 1.0;
        self->_dotContainer.transform = CGAffineTransformIdentity;
        self->_buttonStack.alpha     = 0.0;
        self->_buttonStack.transform = CGAffineTransformMakeScale(0.5, 0.5);
        
        self->_islandWidthConstraint.constant = 48.0;
        self->_islandHeightConstraint.constant = 26.0;
        
        [layoutRoot layoutIfNeeded];
    } completion:nil];
}

- (void)resetCollapseTimer
{
    [_collapseTimer invalidate];
    _collapseTimer = [NSTimer scheduledTimerWithTimeInterval:3.0 target:self selector:@selector(collapseTimerFired) userInfo:nil repeats:NO];
}

- (void)collapseTimerFired
{
    [self collapseIsland];
}

- (UIView *)_dotWithColor:(UIColor *)color
{
    UIView *dot = [[UIView alloc] init];
    dot.translatesAutoresizingMaskIntoConstraints = NO;
    dot.backgroundColor = color;
    dot.layer.cornerRadius = 9.0 / 2.0;
    return dot;
}

- (UIButton *)_islandButtonWithImage:(NSString *)name
                            callback:(void (^)(void))callback
{
    UIButtonConfiguration *cfg = [UIButtonConfiguration plainButtonConfiguration];
    cfg.preferredSymbolConfigurationForImage = [UIImageSymbolConfiguration configurationWithPointSize:16 weight:UIImageSymbolWeightSemibold];
    cfg.image = [UIImage systemImageNamed:name];

    UIButton *btn = [UIButton buttonWithConfiguration:cfg primaryAction:nil];
    btn.translatesAutoresizingMaskIntoConstraints = NO;
    if(callback)
    {
        [btn addAction:[UIAction actionWithHandler:^(__kindof UIAction *a) {
            [self resetCollapseTimer];
            callback();
        }] forControlEvents:UIControlEventTouchUpInside];
    }
    return btn;
}

- (void)dealloc
{
    [_collapseTimer invalidate];
    NSLog(@"deallocated %@", self);
}

@end
