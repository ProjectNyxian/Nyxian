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

#import <LindChain/Multitask/LDEWindow.h>
#import <LindChain/Multitask/ResizeHandleView.h>
#import <LindChain/Private/UIKitPrivate.h>

@interface LDEWindow ()

@property (nonatomic) NSArray* activatedVerticalConstraints;
@property (nonatomic) UIBarButtonItem *maximizeButton;
@property (nonatomic) dispatch_once_t appearOnceAction;

@property (nonatomic, strong) CADisplayLink *resizeDisplayLink;
@property (nonatomic, strong) NSTimer *resizeEndDebounceTimer;
@property (atomic) int resizeEndDebounceRefCnt;
@property (nonatomic) UIView *focusView;

@end

@implementation LDEWindow

- (instancetype)initWithSession:(UIViewController<LDEWindowSession>*)session
                   withDelegate:(id<LDEWindowDelegate>)delegate;
{
    self = [super initWithNibName:nil bundle:nil];
    _session = session;
    _windowName = session.windowName;
    _delegate = delegate;
    
    [self setupDecoratedView:CGRectMake(50, 50, 400, 400)];
    
    // TODO: Reimplement windows for phone
    /*if([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {*/
        UIImage *maximizeImage = [UIImage systemImageNamed:@"arrow.up.left.and.arrow.down.right.circle.fill"];
        UIImageConfiguration *maximizeConfig = [UIImageSymbolConfiguration configurationWithPointSize:16.0 weight:UIImageSymbolWeightMedium];
        maximizeImage = [maximizeImage imageWithConfiguration:maximizeConfig];
        self.maximizeButton = [[UIBarButtonItem alloc] initWithImage:maximizeImage style:UIBarButtonItemStylePlain target:self action:@selector(maximizeButtonPressed)];
        self.maximizeButton.tintColor = [UIColor systemGreenColor];
        
        
        UIImage *closeImage = [UIImage systemImageNamed:@"xmark.circle.fill"];
        UIImageConfiguration *closeConfig = [UIImageSymbolConfiguration configurationWithPointSize:16.0 weight:UIImageSymbolWeightMedium];
        closeImage = [closeImage imageWithConfiguration:closeConfig];
        UIBarButtonItem *closeButton = [[UIBarButtonItem alloc] initWithImage:closeImage style:UIBarButtonItemStylePlain target:self action:@selector(closeWindow)];
        closeButton.tintColor = [UIColor systemRedColor];
        
        NSArray *barButtonItems = @[closeButton, self.maximizeButton];
        self.navigationItem.rightBarButtonItems = barButtonItems;
    //}
    
    return self;
}

- (void)closeWindow
{
    [self.delegate userDidCloseWindow:self];
}

- (void)dismissViewControllerAnimated:(BOOL)flag
                           completion:(void (^)(void))completion
{
    [super dismissViewControllerAnimated:flag completion:completion];
    [self closeWindow];
}

- (void)handlePullDown:(UIPanGestureRecognizer *)gesture
{
    // TODO: Fix this up
    static BOOL isAnimating = NO;
    
    UIView *windowView = self.view;
    CGPoint translation = [gesture translationInView:windowView.superview];
    CGFloat offsetY = MAX(translation.y, 0); // never allow negative
    CGFloat velocityY = [gesture velocityInView:windowView.superview].y;

    switch (gesture.state) {
        case UIGestureRecognizerStateChanged: {
            // Only move downward
            windowView.transform = CGAffineTransformMakeTranslation(0, offsetY);
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled: {
            if (isAnimating) return;
            isAnimating = YES;
            BOOL shouldDismiss = (offsetY > 150 || velocityY > 600);

            if (shouldDismiss) {
                [UIView animateWithDuration:0.3
                                      delay:0
                                    options:UIViewAnimationOptionCurveEaseInOut
                                 animations:^{
                    windowView.transform = CGAffineTransformMakeTranslation(0, windowView.bounds.size.height + 100);
                    windowView.alpha = 0;
                } completion:^(BOOL finished) {
                    if(finished)
                    {
                        windowView.transform = CGAffineTransformIdentity;
                        windowView.alpha = 1.0;
                        [windowView removeFromSuperview];
                        //[self.appSceneVC setForegroundEnabled:NO];
                        //if(self.dismissalCallback != nil) self.dismissalCallback();
                        isAnimating = NO;
                    }
                }];
            } else {
                // Snap back
                [UIView animateWithDuration:0.6
                                      delay:0
                     usingSpringWithDamping:0.8
                      initialSpringVelocity:0.6
                                    options:UIViewAnimationOptionCurveEaseInOut
                                 animations:^{
                                     windowView.transform = CGAffineTransformIdentity;
                } completion:^(BOOL finished){
                    if(finished)
                    {
                        isAnimating = NO;
                    }
                }];
            }
            break;
        }
        default:
            break;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    dispatch_once(&_appearOnceAction, ^{
        [self adjustNavigationBarButtonSpacingWithNegativeSpacing:-8.0 rightMargin:8.0];
        
        // MARK: Suppose to only run on phones
        /*if([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
        {
            [self maximizeWindow:NO];
            UIPanGestureRecognizer *pullDownGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePullDown:)];
            [self.navigationBar addGestureRecognizer:pullDownGesture];
        }
        else
        {*/
            // MARK: Triggering resize system at start to guarantee that it gets layouted
            [self startLiveResizeWithSettingsBlock];
            [self resizeActionStart];
            [self resizeActionEnd];
        //}
    });
}

- (void)unfocusWindow
{
    if (_focusView != nil) return;
    
    _focusView = [[UIView alloc] init];
    [self.view insertSubview:_focusView atIndex:2];
    
    _focusView.backgroundColor = UIColor.secondarySystemFillColor;
    _focusView.alpha = 0.0;
    _focusView.translatesAutoresizingMaskIntoConstraints = NO;
    
    [NSLayoutConstraint activateConstraints:@[
        [_focusView.topAnchor constraintEqualToAnchor:self.navigationBar.bottomAnchor],
        [_focusView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_focusView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_focusView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(focusWindow:)];
    [_focusView addGestureRecognizer:tap];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_focusView.transform = CGAffineTransformMakeScale(1.02, 1.02);
        
        [UIView animateWithDuration:0.22
                              delay:0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            
            self->_focusView.alpha = 0.12;
            self->_focusView.transform = CGAffineTransformIdentity;
            
            // Smooth background color transition
            [UIView transitionWithView:self->_navigationBar
                              duration:0.22
                               options:UIViewAnimationOptionTransitionCrossDissolve
                            animations:^{
                self->_navigationBar.backgroundColor = UIColor.grayColor;
            } completion:nil];
            
        } completion:nil];
    });
}

- (void)focusWindow:(UIPanGestureRecognizer*)sender
{
    if (!_focusView) return;

    [UIView animateWithDuration:0.18
                          delay:0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        self->_focusView.alpha = 0.0;
        self->_focusView.transform = CGAffineTransformMakeScale(1.02, 1.02);

        [UIView transitionWithView:self->_navigationBar
                          duration:0.18
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^{
            self->_navigationBar.backgroundColor = UIColor.quaternarySystemFillColor;
        } completion:nil];

    } completion:^(BOOL finished) {
        [self->_focusView removeFromSuperview];
        self->_focusView = nil;
        [self.delegate userDidFocusWindow:self];
    }];
}

- (void)setupDecoratedView:(CGRect)dimensions
{
    UIView *shadowContainer = [[UIStackView alloc] initWithFrame:dimensions];
    shadowContainer.backgroundColor = UIColor.clearColor;
    shadowContainer.autoresizingMask = UIViewAutoresizingNone;
    
    shadowContainer.layer.shadowColor = UIColor.blackColor.CGColor;
    shadowContainer.layer.shadowOpacity = 1.0;
    shadowContainer.layer.shadowRadius = 12;
    shadowContainer.layer.shadowOffset = CGSizeMake(0, 4);
    
    UIStackView *contentStack = [UIStackView new];
    contentStack.frame = shadowContainer.bounds;
    contentStack.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    contentStack.axis = UILayoutConstraintAxisVertical;
    contentStack.backgroundColor = UIColor.systemBackgroundColor;
    contentStack.layer.cornerRadius = 10;
    contentStack.layer.masksToBounds = YES;
    [shadowContainer addSubview:contentStack];
    self.view = shadowContainer;
    
    UINavigationBar *navigationBar = [[UINavigationBar alloc] init];
    navigationBar.backgroundColor = UIColor.quaternarySystemFillColor;
    navigationBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UINavigationItem *navigationItem = [[UINavigationItem alloc] initWithTitle:_windowName];
    navigationBar.items = @[navigationItem];
    
    self.navigationBar = navigationBar;
    self.navigationItem = navigationItem;
    [contentStack addArrangedSubview:navigationBar];
    
    CGRect contentFrame = CGRectMake(0, 0,
                                     contentStack.frame.size.width,
                                     contentStack.frame.size.height);
    
    UIView *fixedPositionContentView = [[UIView alloc] initWithFrame:contentFrame];
    fixedPositionContentView.autoresizingMask =
    UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    [contentStack addArrangedSubview:fixedPositionContentView];
    [contentStack sendSubviewToBack:fixedPositionContentView];
    
    self.contentView = [[UIView alloc] initWithFrame:contentFrame];
    self.contentView.layer.anchorPoint = CGPointMake(0, 0);
    self.contentView.layer.position = CGPointMake(0, 0);
    self.contentView.autoresizingMask =
    UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    [fixedPositionContentView addSubview:self.contentView];
    
    UIPanGestureRecognizer *moveGesture =
    [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveWindow:)];
    moveGesture.minimumNumberOfTouches = 1;
    moveGesture.maximumNumberOfTouches = 1;
    [self.navigationBar addGestureRecognizer:moveGesture];
    
    UIPanGestureRecognizer *resizeGesture =
    [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(resizeWindow:)];
    resizeGesture.minimumNumberOfTouches = 1;
    resizeGesture.maximumNumberOfTouches = 1;
    
    self.resizeHandle = [[ResizeHandleView alloc] initWithFrame:CGRectMake(contentStack.frame.size.width - 44, contentStack.frame.size.height - 44, 44, 44)];
    [self.resizeHandle addGestureRecognizer:resizeGesture];
    [contentStack addSubview:self.resizeHandle];
    
    contentStack.layer.borderWidth = 0.5;
    contentStack.layer.borderColor = UIColor.systemGray3Color.CGColor;
    
    [self addChildViewController:_session];
    [contentStack insertSubview:_session.view atIndex:0];
    
    _session.view.translatesAutoresizingMaskIntoConstraints = NO;
    
    [NSLayoutConstraint activateConstraints:@[
        [_session.view.topAnchor constraintEqualToAnchor:navigationBar.bottomAnchor],
        [_session.view.leadingAnchor constraintEqualToAnchor:contentStack.leadingAnchor]
    ]];
    
    [self updateVerticalConstraints];
    [self updateOriginalFrame];
}

- (void)maximizeWindow:(BOOL)animated {
    [self resizeActionStart];
    if (self.isMaximized) {
        CGRect maxFrame = UIEdgeInsetsInsetRect(self.view.window.frame, self.view.window.safeAreaInsets);
        CGRect newFrame = CGRectMake(self.originalFrame.origin.x * maxFrame.size.width, self.originalFrame.origin.y * maxFrame.size.height, self.originalFrame.size.width, self.originalFrame.size.height);
        [UIView animateWithDuration:animated ? 0.3 : 0.0 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.view.frame = newFrame;
            self.view.layer.borderWidth = 1;
            self.resizeHandle.alpha = 1;
        } completion:^(BOOL finished) {
            self.isMaximized = NO;
            UIImage *maximizeImage = [UIImage systemImageNamed:@"arrow.up.left.and.arrow.down.right.circle.fill"];
            UIImageConfiguration *maximizeConfig = [UIImageSymbolConfiguration configurationWithPointSize:16.0 weight:UIImageSymbolWeightMedium];
            self.maximizeButton.image = [maximizeImage imageWithConfiguration:maximizeConfig];
            [self resizeActionEnd];
        }];
    } else {
        [self.view.superview bringSubviewToFront:self.view];
        [self updateOriginalFrame];
        [UIView animateWithDuration:animated ? 0.3 : 0.0 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.isMaximized = YES;
            [self updateVerticalConstraints];
            
            self.view.layer.borderWidth = 0;
            self.resizeHandle.alpha = 0;
        } completion:^(BOOL finished) {
            UIImage *restoreImage = [UIImage systemImageNamed:@"arrow.down.right.and.arrow.up.left.circle.fill"];
            UIImageConfiguration *restoreConfig = [UIImageSymbolConfiguration configurationWithPointSize:16.0 weight:UIImageSymbolWeightMedium];
            self.maximizeButton.image = [restoreImage imageWithConfiguration:restoreConfig];
            [self resizeActionEnd];
        }];
    }
}

- (void)maximizeButtonPressed
{
    [self maximizeWindow:YES];
}

- (void)adjustNavigationBarButtonSpacingWithNegativeSpacing:(CGFloat)spacing rightMargin:(CGFloat)margin {
    if (!self.navigationBar) return;
    [self findAndAdjustButtonBarStackView:self.navigationBar withSpacing:spacing sideMargin:margin];
}

- (void)findAndAdjustButtonBarStackView:(UIView *)view withSpacing:(CGFloat)spacing sideMargin:(CGFloat)margin {
    for (UIView *subview in view.subviews) {
        if ([subview isKindOfClass:NSClassFromString(@"_UIButtonBarStackView")]) {
            if ([subview respondsToSelector:@selector(setSpacing:)]) {
                [(_UIButtonBarStackView *)subview setSpacing:spacing];
            }
            
            if (subview.superview) {
                for (NSLayoutConstraint *constraint in subview.superview.constraints) {
                    if ((constraint.firstItem == subview && constraint.firstAttribute == NSLayoutAttributeTrailing) ||
                        (constraint.secondItem == subview && constraint.secondAttribute == NSLayoutAttributeTrailing)) {
                        constraint.constant = (constraint.firstItem == subview) ? -margin : margin;
                        break;
                    }
                }
                
                for (NSLayoutConstraint *constraint in subview.superview.constraints) {
                    if ((constraint.firstItem == subview && constraint.firstAttribute == NSLayoutAttributeLeading) ||
                        (constraint.secondItem == subview && constraint.secondAttribute == NSLayoutAttributeLeading)) {
                        constraint.constant = (constraint.firstItem == subview) ? -margin : margin;
                        break;
                    }
                }
                
                [subview setNeedsLayout];
                [subview.superview setNeedsLayout];
            }
            
            return;
        }
        
        [self findAndAdjustButtonBarStackView:subview withSpacing:spacing sideMargin:margin];
    }
}

- (void)moveWindow:(UIPanGestureRecognizer*)sender
{
    if(_isMaximized) return;
    
    CGPoint point = [sender translationInView:self.view];
    [sender setTranslation:CGPointZero inView:self.view];
    CGPoint newPosition = CGPointMake(self.view.center.x + point.x, self.view.center.y + point.y);
    CGRect newRect = CGRectMake(
        newPosition.x - self.view.bounds.size.width / 2.0,
        newPosition.y - self.view.bounds.size.height / 2.0,
        self.view.bounds.size.width,
        self.view.bounds.size.height
    );
    newRect = [self.delegate userDoesChangeWindow:self toRect:newRect];
    self.view.frame = newRect;
    
    [self updateOriginalFrame];
}

- (void)resizeWindow:(UIPanGestureRecognizer*)gesture
{
    if(_isMaximized) return;
    
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
            [self resizeActionStart];
            break;
        case UIGestureRecognizerStateChanged:
        {
            CGPoint point = [gesture translationInView:self.view.superview];
            [gesture setTranslation:CGPointZero inView:self.view.superview];
            CGRect oldFrame = self.view.frame;
            CGRect proposed = oldFrame;
            proposed.size.width  = MAX(50, proposed.size.width  + point.x);
            proposed.size.height = MAX(50, proposed.size.height + point.y);
            CGRect corrected = [self.delegate userDoesChangeWindow:self toRect:proposed];
            
            BOOL widthBlocked  = (corrected.origin.x != proposed.origin.x);
            BOOL heightBlocked = (corrected.origin.y != proposed.origin.y);

            if(widthBlocked)
            {
                corrected.size.width = oldFrame.size.width;
                corrected.origin.x   = oldFrame.origin.x;
            }

            if(heightBlocked)
            {
                corrected.size.height = oldFrame.size.height;
                corrected.origin.y    = oldFrame.origin.y;
            }

            self.view.frame = corrected;
            [self updateOriginalFrame];
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            [self resizeActionEnd];
            break;
        default:
            break;
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    // FIXME: how to bring view to front when touching the passthrough view?
    [self.view.superview bringSubviewToFront:self.view];
    [self focusWindow:nil];
}

- (void)updateVerticalConstraints
{
    // Update safe area insets
    /*if(_isMaximized)
    {
        __weak typeof(self) weakSelf = self;
        self.appSceneVC.nextUpdateSettingsBlock = ^(UIMutableApplicationSceneSettings *settings)
        {
            [weakSelf updateMaximizedFrameWithSettings:settings];
        };
    }*/
    
    /*[NSLayoutConstraint deactivateConstraints:self.activatedVerticalConstraints];
    self.activatedVerticalConstraints = @[
        [self.session.view.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:44],
        [self.session.view.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [self.navigationBar.heightAnchor constraintEqualToConstant:44]
    ];
    [NSLayoutConstraint activateConstraints:self.activatedVerticalConstraints];*/
}

/*- (UIEdgeInsets)updateMaximizedSafeAreaWithSettings:(UIMutableApplicationSceneSettings *)settings
{
    UIEdgeInsets safeAreaInsets = self.view.window.safeAreaInsets;
    settings.peripheryInsets = UIEdgeInsetsMake(0, safeAreaInsets.left, safeAreaInsets.bottom, safeAreaInsets.right);
    safeAreaInsets.bottom = safeAreaInsets.left = safeAreaInsets.right = 0;
    
    // scale peripheryInsets to match the scale ratio
    settings.peripheryInsets = UIEdgeInsetsMake(settings.peripheryInsets.top/_scaleRatio, settings.peripheryInsets.left/_scaleRatio, settings.peripheryInsets.bottom/_scaleRatio, settings.peripheryInsets.right/_scaleRatio);
    
    if(UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPad)
    {
        UIInterfaceOrientation currentOrientation = UIApplication.sharedApplication.statusBarOrientation;
        if(UIInterfaceOrientationIsLandscape(currentOrientation)) {
            safeAreaInsets.top = 0;
        }
        switch(currentOrientation) {
            case UIInterfaceOrientationLandscapeLeft:
                settings.safeAreaInsetsPortrait = UIEdgeInsetsMake(settings.peripheryInsets.left, 0, settings.peripheryInsets.right, settings.peripheryInsets.bottom);
                break;
            case UIInterfaceOrientationLandscapeRight:
                settings.safeAreaInsetsPortrait = UIEdgeInsetsMake(settings.peripheryInsets.left, settings.peripheryInsets.bottom, settings.peripheryInsets.right, 0);
                break;
            default:
                settings.safeAreaInsetsPortrait = UIEdgeInsetsMake(settings.peripheryInsets.top, settings.peripheryInsets.left, settings.peripheryInsets.bottom, settings.peripheryInsets.right);
                break;
        }
        
    } else {
        settings.safeAreaInsetsPortrait = UIEdgeInsetsMake(settings.peripheryInsets.top, settings.peripheryInsets.left, settings.peripheryInsets.bottom, settings.peripheryInsets.right);
    }
    
    safeAreaInsets.bottom = 0;
    return safeAreaInsets;
}

- (void)updateMaximizedFrameWithSettings:(UIMutableApplicationSceneSettings *)settings {
    CGRect maxFrame = UIEdgeInsetsInsetRect(self.view.window.frame, [self updateMaximizedSafeAreaWithSettings:settings]);
    self.view.frame = maxFrame;
}

- (void)updateWindowedFrameWithSettings:(UIMutableApplicationSceneSettings *)settings {
    UIEdgeInsets safeAreaInsets = self.view.window.safeAreaInsets;
    CGRect maxFrame = UIEdgeInsetsInsetRect(self.view.window.frame, safeAreaInsets);
    settings.peripheryInsets = UIEdgeInsetsZero;
    settings.safeAreaInsetsPortrait = UIEdgeInsetsZero;
    
    CGRect newFrame = CGRectMake(self.originalFrame.origin.x * maxFrame.size.width, self.originalFrame.origin.y * maxFrame.size.height, self.originalFrame.size.width, self.originalFrame.size.height);
    CGPoint center = self.view.center;
    CGRect frame = CGRectZero;
    frame.size.width = MIN(newFrame.size.width, maxFrame.size.width);
    frame.size.height = MIN(newFrame.size.height, maxFrame.size.height);
    CGFloat oobOffset = MAX(30, frame.size.width - 30);
    frame.origin.x = MAX(maxFrame.origin.x - oobOffset, MIN(CGRectGetMaxX(maxFrame) - frame.size.width + oobOffset, center.x - frame.size.width / 2));
    frame.origin.y = MAX(maxFrame.origin.y, MIN(center.y - frame.size.height / 2, CGRectGetMaxY(maxFrame) - frame.size.height));
    [UIView animateWithDuration:0.3 animations:^{
        self.view.frame = frame;
    }];
}*/

- (void)updateOriginalFrame {
    CGRect maxFrame = UIEdgeInsetsInsetRect(self.view.window.frame, self.view.window.safeAreaInsets);
    // save origin as normalized coordinates
    self.originalFrame = CGRectMake(self.view.frame.origin.x / maxFrame.size.width, self.view.frame.origin.y / maxFrame.size.height, self.view.frame.size.width, self.view.frame.size.height);
}

/*
 * Resize Handling
 *
 */
- (void)startLiveResizeWithSettingsBlock
{
    if(!self.resizeDisplayLink)
    {
        self.resizeDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateSceneFrame)];
        [self.resizeDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        self.resizeDisplayLink.paused = YES;
    }
}

- (void)updateSceneFrame
{
    CGFloat navBarHeight = self.navigationBar.frame.size.height;
    
    CGRect frame = CGRectMake(self.view.frame.origin.x,
                              self.view.frame.origin.y + navBarHeight,
                              self.view.frame.size.width,
                              self.view.frame.size.height - navBarHeight);
    
    [_session windowChangesSizeToRect:frame];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    [self endLiveResize];
}

- (void)endLiveResize
{
    [self.resizeDisplayLink invalidate];
    self.resizeDisplayLink = nil;
}

- (void)resizeActionStart
{
    if(_resizeEndDebounceRefCnt == 0)
    {
        [self.resizeEndDebounceTimer invalidate];
        self.resizeEndDebounceTimer = nil;
        self.resizeDisplayLink.paused = NO;
    }
    
    _resizeEndDebounceRefCnt += 1;
}

- (void)resizeActionEnd
{
    if(_resizeEndDebounceRefCnt == 0)
        return;
    else
        _resizeEndDebounceRefCnt -= 1;
    
    if(_resizeEndDebounceRefCnt == 0)
    {
        [self.resizeEndDebounceTimer invalidate];
        __weak typeof(self) weakSelf = self;
        self.resizeEndDebounceTimer = [NSTimer scheduledTimerWithTimeInterval:0.5 repeats:NO block:^(NSTimer * _Nonnull timer) {
            weakSelf.resizeDisplayLink.paused = YES;
            weakSelf.resizeEndDebounceTimer = nil;
        }];
    }
}

@end
