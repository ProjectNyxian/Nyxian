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

#import <LindChain/Multitask/WindowServer/LDEWindow.h>
#import <LindChain/Multitask/WindowServer/ResizeHandleView.h>
#import <LindChain/Private/UIKitPrivate.h>

@interface LDEWindow ()

@property (nonatomic) NSArray* activatedVerticalConstraints;
@property (nonatomic) UIBarButtonItem *maximizeButton;
@property (nonatomic) dispatch_once_t appearOnceAction;

@property (nonatomic, strong) CADisplayLink *resizeDisplayLink;
@property (nonatomic, strong) NSTimer *resizeEndDebounceTimer;
@property (atomic) int resizeEndDebounceRefCnt;
@property (nonatomic) UIView *focusView;

// Intuition Fixup
@property CGPoint resizeAnchor;
@property CGPoint grabOffset;

@end

@implementation LDEWindow

- (instancetype)initWithSession:(UIViewController<LDEWindowSession>*)session
                   withDelegate:(id<LDEWindowDelegate>)delegate;
{
    self = [super initWithNibName:nil bundle:nil];
    _session = session;
    _session.windowIsFullscreen = NO;
    _windowName = session.windowName;
    _delegate = delegate;
    
    [self setupDecoratedView:[_delegate userDoesChangeWindow:self toRect:[_session windowRect]]];
    
    if([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
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
        self.navigationItem.leftBarButtonItems = barButtonItems;
    }
    
    return self;
}

- (void)closeWindow
{
    [UIView animateKeyframesWithDuration:0.25 delay:0 options:UIViewKeyframeAnimationOptionCalculationModeCubic animations:^{
        [UIView addKeyframeWithRelativeStartTime:0.0 relativeDuration:0.25 animations:^{
            self.view.alpha = 0.8;
            self.view.transform = CGAffineTransformMakeScale(1.05, 1.05);
        }];
        [UIView addKeyframeWithRelativeStartTime:0.25 relativeDuration:0.75 animations:^{
            self.view.alpha = 0.0;
            self.view.transform = CGAffineTransformMakeScale(0.6, 0.6);
        }];
    } completion:^(BOOL finished) {
        self.view.transform = CGAffineTransformIdentity;
        [self.session closeWindowWithScene:self.delegate.windowScene withFrame:self.originalFrame];
        [self.delegate userDidCloseWindow:self];
    }];
}

- (void)openWindow
{
    self.view.alpha = 0.0;
    self.view.transform = CGAffineTransformMakeScale(0.6, 0.6);
    [UIView animateKeyframesWithDuration:0.28 delay:0 options:UIViewKeyframeAnimationOptionCalculationModeCubic animations:^{
        [UIView addKeyframeWithRelativeStartTime:0.0 relativeDuration:0.5 animations:^{
            self.view.alpha = 1.0;
            self.view.transform = CGAffineTransformMakeScale(1.05, 1.05);
        }];
        [UIView addKeyframeWithRelativeStartTime:0.5 relativeDuration:0.5 animations:^{
            self.view.transform = CGAffineTransformIdentity;
        }];
    } completion:nil];
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
                        if(self.isMaximized)
                        {
                            [self maximizeWindow:NO];
                        }
                        [windowView removeFromSuperview];
                        [self.session deactivateWindow];
                        [self.delegate userDidMinimizeWindow:self];
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
        [self adjustNavigationBarButtonSpacingWithNegativeSpacing:-10.0 rightMargin:6.0];
        
        // MARK: Suppose to only run on phones
        [self startLiveResizeWithSettingsBlock];
        if([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
        {
            [self maximizeWindow:NO];
            UIPanGestureRecognizer *pullDownGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePullDown:)];
            [self.navigationBar addGestureRecognizer:pullDownGesture];
        }
        else
        {
            // MARK: Triggering resize system at start to guarantee that it gets layouted
            [self resizeActionStart];
            [self resizeActionEnd];
        }
    });
}

- (void)unfocusWindow
{
    if (_focusView != nil) return;
    
    _focusView = [[UIView alloc] init];
    _focusView.backgroundColor = UIColor.secondarySystemFillColor;
    _focusView.alpha = 0.0;
    _focusView.translatesAutoresizingMaskIntoConstraints = NO;
    [self.contentStack insertSubview:_focusView aboveSubview:self.session.view];
    
    [NSLayoutConstraint activateConstraints:@[
        [_focusView.topAnchor constraintEqualToAnchor:self.navigationBar.bottomAnchor],
        [_focusView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],
        [_focusView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [_focusView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor]
    ]];
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(focusWindow:)];
    tap.delegate = self;
    [_focusView addGestureRecognizer:tap];
    
    dispatch_async(dispatch_get_main_queue(), ^{
        self->_focusView.transform = CGAffineTransformMakeScale(1.02, 1.02);
        
        [UIView animateWithDuration:0.11
                              delay:0
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
            
            self->_focusView.alpha = 0.12;
            self->_focusView.transform = CGAffineTransformIdentity;
            
            // Smooth background color transition
            [UIView transitionWithView:self->_navigationBar
                              duration:0.11
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
    [self.view.superview bringSubviewToFront:self.view];

    [UIView animateWithDuration:0.11
                          delay:0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        self->_focusView.alpha = 0.0;
        self->_focusView.transform = CGAffineTransformMakeScale(1.02, 1.02);

        [UIView transitionWithView:self->_navigationBar
                          duration:0.11
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

- (void)focusWindow
{
    dispatch_async(dispatch_get_main_queue(), ^{
        [self focusWindow:nil];
    });
}

- (void)setupDecoratedView:(CGRect)dimensions
{
    self.view = [[UIStackView alloc] initWithFrame:dimensions];
    self.view.backgroundColor = UIColor.clearColor;
    self.view.autoresizingMask = UIViewAutoresizingNone;
    
    self.view.layer.shadowColor = UIColor.blackColor.CGColor;
    self.view.layer.shadowOpacity = 1.0;
    self.view.layer.shadowRadius = 12;
    self.view.layer.shadowOffset = CGSizeMake(0, 0);
    
    self.contentStack = [UIStackView new];
    self.contentStack.frame = self.view.bounds;
    self.contentStack.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    self.contentStack.axis = UILayoutConstraintAxisVertical;
    self.contentStack.backgroundColor = UIColor.systemBackgroundColor;
    self.contentStack.layer.cornerRadius = 20;
    self.contentStack.layer.masksToBounds = YES;
    [self.view addSubview:self.contentStack];
    
    UINavigationBar *navigationBar = [[UINavigationBar alloc] init];
    navigationBar.backgroundColor = UIColor.quaternarySystemFillColor;
    navigationBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UINavigationItem *navigationItem = [[UINavigationItem alloc] initWithTitle:_windowName];
    navigationBar.items = @[navigationItem];
    
    self.navigationBar = navigationBar;
    self.navigationItem = navigationItem;
    [self.contentStack addArrangedSubview:navigationBar];
    
    CGRect contentFrame = CGRectMake(0, 0,
                                     self.contentStack.frame.size.width,
                                     self.contentStack.frame.size.height);
    
    UIView *fixedPositionContentView = [[UIView alloc] initWithFrame:contentFrame];
    fixedPositionContentView.autoresizingMask =
    UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    [self.contentStack addArrangedSubview:fixedPositionContentView];
    [self.contentStack sendSubviewToBack:fixedPositionContentView];
    
    if(UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPhone)
    {
        UIPanGestureRecognizer *moveGesture =
        [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveWindow:)];
        moveGesture.minimumNumberOfTouches = 1;
        moveGesture.maximumNumberOfTouches = 1;
        [self.navigationBar addGestureRecognizer:moveGesture];
        
        UITapGestureRecognizer *fullScreenGesture =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(maximizeButtonPressed)];
        fullScreenGesture.numberOfTapsRequired = 2;
        fullScreenGesture.numberOfTouchesRequired = 1;
        fullScreenGesture.delaysTouchesBegan = NO;
        fullScreenGesture.delaysTouchesEnded = NO;
        fullScreenGesture.cancelsTouchesInView = NO;
        [self.navigationBar addGestureRecognizer:fullScreenGesture];
        
        moveGesture.delegate = self;
        fullScreenGesture.delegate = self;
    }
    
    UIPanGestureRecognizer *resizeGesture =
    [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(resizeWindow:)];
    resizeGesture.minimumNumberOfTouches = 1;
    resizeGesture.maximumNumberOfTouches = 1;
    
    self.resizeHandle = [[ResizeHandleView alloc] initWithFrame:CGRectMake(self.contentStack.frame.size.width - 44, self.contentStack.frame.size.height - 44, 44, 44)];
    [self.resizeHandle addGestureRecognizer:resizeGesture];
    [self.contentStack addSubview:self.resizeHandle];
    
    self.contentStack.layer.borderWidth = 0.5;
    self.contentStack.layer.borderColor = UIColor.systemGray3Color.CGColor;
    
    [self addChildViewController:_session];
    [self.contentStack insertSubview:_session.view atIndex:0];
    
    _session.view.translatesAutoresizingMaskIntoConstraints = NO;
    
    [NSLayoutConstraint activateConstraints:@[
        [_session.view.topAnchor constraintEqualToAnchor:navigationBar.bottomAnchor],
        [_session.view.leadingAnchor constraintEqualToAnchor:self.contentStack.leadingAnchor]
    ]];
    
    [self updateOriginalFrame];
    self.view.alpha = 0.0;
    
}

- (void)maximizeWindow:(BOOL)animated
{
    [self focusWindow:nil];
    
    [self resizeActionStart];
    if(self.isMaximized)
    {
        self.isMaximized = NO;
        self.session.windowIsFullscreen = NO;
        CGRect newFrame = [self.delegate userDoesChangeWindow:self toRect:self.originalFrame];
        [UIView animateWithDuration:(animated ? 0.35 : 0) delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.view.frame = newFrame;
            self.contentStack.layer.cornerRadius = 20;
            self.contentStack.layer.borderWidth = 0.5;
            self.view.layer.shadowOpacity = 1.0;
            self.resizeHandle.hidden = NO;
        } completion:^(BOOL finished){
            [self resizeActionEnd];
        }];
    } else
    {
        self.isMaximized = YES;
        self.session.windowIsFullscreen = YES;
        CGRect newFrame = [self.delegate userDoesChangeWindow:self toRect:CGRectZero];
        [UIView animateWithDuration:(animated ? 0.35 : 0) delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.view.frame = newFrame;
            self.contentStack.layer.cornerRadius = 0;
            self.contentStack.layer.borderWidth = 0;
            self.view.layer.shadowOpacity = 0;
            self.resizeHandle.hidden = YES;
        } completion:^(BOOL finished){
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
    for(UIView *subview in view.subviews)
    {
        if([subview isKindOfClass:NSClassFromString(@"_UIButtonBarStackView")])
        {
            if ([subview respondsToSelector:@selector(setSpacing:)]) {
                [(_UIButtonBarStackView *)subview setSpacing:spacing];
            }
            
            if (subview.superview)
            {
                for(NSLayoutConstraint *constraint in subview.superview.constraints)
                {
                    if((constraint.firstItem == subview && constraint.firstAttribute == NSLayoutAttributeTrailing) ||
                       (constraint.secondItem == subview && constraint.secondAttribute == NSLayoutAttributeTrailing))
                    {
                        constraint.constant = (constraint.firstItem == subview) ? -margin : margin;
                        break;
                    }
                    
                    if((constraint.firstItem == subview && constraint.firstAttribute == NSLayoutAttributeLeading) ||
                       (constraint.secondItem == subview && constraint.secondAttribute == NSLayoutAttributeLeading))
                    {
                        constraint.constant = (constraint.firstItem == subview) ? margin : -margin;
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

- (void)moveWindow:(UIPanGestureRecognizer*)gesture
{
    if(_isMaximized) return;

    CGPoint finger = [gesture locationInView:self.view.superview];

    switch(gesture.state)
    {

        case UIGestureRecognizerStateBegan:
        {
            [self focusWindow];
            CGPoint pointInWindow = [gesture locationInView:self.view];
            self.grabOffset = pointInWindow;
            break;
        }
        case UIGestureRecognizerStateChanged:
        {
            CGRect frame = self.view.frame;
            frame.origin.x = finger.x - self.grabOffset.x;
            frame.origin.y = finger.y - self.grabOffset.y;
            frame = [self.delegate userDoesChangeWindow:self toRect:frame];
            self.view.frame = frame;
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            [self updateOriginalFrame];
        default:
            break;
    }
}

- (void)resizeWindow:(UIPanGestureRecognizer*)gesture
{
    if(_isMaximized) return;

    CGPoint finger = [gesture locationInView:self.view.superview];

    switch(gesture.state)
    {
        case UIGestureRecognizerStateBegan:
        {
            [self focusWindow];
            [self resizeActionStart];
            self.resizeAnchor = CGPointMake(
                CGRectGetMinX(self.view.frame),
                CGRectGetMinY(self.view.frame)
            );
            break;
        }
        case UIGestureRecognizerStateChanged:
        {
            CGFloat newWidth  = finger.x - self.resizeAnchor.x;
            CGFloat newHeight = finger.y - self.resizeAnchor.y;
            
            CGRect oldFrame = self.view.frame;
            CGRect proposed = oldFrame;
            proposed.size.width = MAX(300, newWidth);
            proposed.size.height = MAX(200, newHeight);
            
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
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            [self resizeActionEnd];
            [self updateOriginalFrame];
            break;
        default:
            break;
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [super touchesBegan:touches withEvent:event];
    [self focusWindow:nil];
}

- (void)updateOriginalFrame
{
    self.originalFrame = self.view.frame;
}

- (void)changeWindowToRect:(CGRect)rect
                completion:(void (^)(BOOL))completion
{
    [self resizeActionStart];
    [UIView animateWithDuration:0.35
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         self.view.frame = rect;
    } completion:^(BOOL finished){
        [self resizeActionEnd];
        if(completion != nil) completion(finished);
    }];
}

- (void)changeWindowToRect:(CGRect)rect
{
    [self changeWindowToRect:rect completion:nil];
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

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer
        shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
    return YES;
}

@end

