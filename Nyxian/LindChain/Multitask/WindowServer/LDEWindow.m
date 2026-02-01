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
#import <LindChain/Multitask/WindowServer/LDEWindowBar.h>
#import <LindChain/Private/UIKitPrivate.h>

@interface LDEWindow ()

@property (nonatomic) NSArray* activatedVerticalConstraints;
@property (nonatomic) UIBarButtonItem *maximizeButton;
@property (nonatomic) dispatch_once_t appearOnceAction;

@property (nonatomic, strong) CADisplayLink *resizeDisplayLink;
@property (nonatomic, strong) NSTimer *resizeEndDebounceTimer;
@property (atomic) int resizeEndDebounceRefCnt;
@property (nonatomic) UIView *focusView;
@property (nonatomic) LDEWindowBar *windowBar;

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
    
    [self setupDecoratedView:[_delegate window:self wantsToChangeToRect:[_session windowRect]]];
    
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
        [self.delegate windowWantsToClose:self];
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
    UIView *windowView = self.view;
    
    switch(gesture.state)
    {
        case UIGestureRecognizerStateBegan:
            [windowView.layer removeAllAnimations];
            break;
        case UIGestureRecognizerStateChanged:
        {
            CGPoint translation = [gesture translationInView:windowView.superview];
            CGFloat offsetY = MAX(translation.y, 0);
            windowView.transform = CGAffineTransformMakeTranslation(0, offsetY);
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        {
            CGPoint translation = [gesture translationInView:windowView.superview];
            CGFloat offsetY = MAX(translation.y, 0);
            CGFloat velocityY = [gesture velocityInView:windowView.superview].y;
            BOOL shouldDismiss = (offsetY > 150 || velocityY > 600);
            if(shouldDismiss)
            {
                [UIView animateWithDuration:0.3 delay:0 options:UIViewAnimationOptionCurveEaseInOut | UIViewAnimationOptionBeginFromCurrentState animations:^{
                    windowView.transform = CGAffineTransformMakeTranslation(0, windowView.bounds.size.height + 100);
                    windowView.alpha = 0;
                } completion:^(BOOL finished) {
                    windowView.transform = CGAffineTransformIdentity;
                    windowView.alpha = 1.0;
                    [windowView removeFromSuperview];
                    [self.session deactivateWindow];
                    [self.delegate windowWantsToMinimize:self];
                }];
            }
            else
            {
                [UIView animateWithDuration:0.6 delay:0 usingSpringWithDamping:0.8 initialSpringVelocity:velocityY / 1000.0 options:UIViewAnimationOptionBeginFromCurrentState animations:^{
                    windowView.transform = CGAffineTransformIdentity;
                } completion:nil];
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
        // MARK: Suppose to only run on phones
        [self startLiveResizeWithSettingsBlock];
        if([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
        {
            [self maximizeWindow:NO];
            UIPanGestureRecognizer *pullDownGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePullDown:)];
            [self.windowBar addGestureRecognizer:pullDownGesture];
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
        [_focusView.topAnchor constraintEqualToAnchor:self.windowBar.bottomAnchor],
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
                self->_windowBar.backgroundColor = UIColor.grayColor;
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
            self->_windowBar.backgroundColor = UIColor.quaternarySystemFillColor;
        } completion:nil];

    } completion:^(BOOL finished) {
        [self->_focusView removeFromSuperview];
        self->_focusView = nil;
        [self.delegate windowWantsToFocus:self];
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
    if(UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone)
    {
        self.contentStack.layer.maskedCorners = kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    }
    self.contentStack.layer.masksToBounds = YES;
    [self.view addSubview:self.contentStack];
    
    __weak typeof(self) weakSelf = self;
    LDEWindowBar *windowBar = [[LDEWindowBar alloc] initWithTitle:self.windowName withCloseCallback:^{
        [weakSelf closeWindow];
    } withMaximizeCallback:^{
        [weakSelf maximizeWindow:YES];
    }];
    
    windowBar.backgroundColor = UIColor.quaternarySystemFillColor;
    [self.contentStack addArrangedSubview:windowBar];
    
    [NSLayoutConstraint activateConstraints:@[
        [windowBar.topAnchor constraintEqualToAnchor:self.contentStack.topAnchor],
        [windowBar.leadingAnchor constraintEqualToAnchor:self.contentStack.leadingAnchor],
        [windowBar.trailingAnchor constraintEqualToAnchor:self.contentStack.trailingAnchor],
    ]];
    self.windowBar = windowBar;
    
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
        [self.windowBar addGestureRecognizer:moveGesture];
        
        UITapGestureRecognizer *fullScreenGesture =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(maximizeButtonPressed)];
        fullScreenGesture.numberOfTapsRequired = 2;
        fullScreenGesture.numberOfTouchesRequired = 1;
        fullScreenGesture.delaysTouchesBegan = NO;
        fullScreenGesture.delaysTouchesEnded = NO;
        fullScreenGesture.cancelsTouchesInView = NO;
        [self.windowBar addGestureRecognizer:fullScreenGesture];
        
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
        [_session.view.topAnchor constraintEqualToAnchor:windowBar.bottomAnchor],
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
        CGRect newFrame = [self.delegate window:self wantsToChangeToRect:self.originalFrame];
        CGRect newNavigationBar = self.windowBar.frame;
        newNavigationBar.size.width = newFrame.size.width;
        [UIView animateWithDuration:(animated ? 0.35 : 0) delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.view.frame = newFrame;
            self.windowBar.frame = newNavigationBar;
            if(UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPhone)
            {
                self.contentStack.layer.cornerRadius = 20;
            }
            self.contentStack.layer.borderWidth = 0.5;
            self.view.layer.shadowOpacity = 1.0;
            self.resizeHandle.hidden = NO;
        } completion:^(BOOL finished){
            if(finished)
            {
                [self resizeActionEnd];
                self.windowBar.maximizeButton.imageView.image = [UIImage systemImageNamed:@"arrow.up.left.and.arrow.down.right.circle.fill"];
            }
        }];
    } else
    {
        self.isMaximized = YES;
        self.session.windowIsFullscreen = YES;
        CGRect newFrame = [self.delegate window:self wantsToChangeToRect:CGRectZero];
        CGRect newNavigationBar = self.windowBar.frame;
        newNavigationBar.size.width = newFrame.size.width;
        [UIView animateWithDuration:(animated ? 0.35 : 0) delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.view.frame = newFrame;
            self.windowBar.frame = newNavigationBar;
            if(UIDevice.currentDevice.userInterfaceIdiom != UIUserInterfaceIdiomPhone)
            {
                self.contentStack.layer.cornerRadius = 0;
            }
            self.contentStack.layer.borderWidth = 0;
            self.view.layer.shadowOpacity = 0;
            self.resizeHandle.hidden = YES;
        } completion:^(BOOL finished){
            if(finished)
            {
                [self resizeActionEnd];
                self.windowBar.maximizeButton.imageView.image = [UIImage systemImageNamed:@"arrow.down.right.and.arrow.up.left.circle.fill"];
            }
        }];
    }
}

- (void)maximizeButtonPressed
{
    [self maximizeWindow:YES];
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
            [self resizeActionStart];
            break;
        }
        case UIGestureRecognizerStateChanged:
        {
            CGRect frame = self.view.frame;
            frame.origin.x = finger.x - self.grabOffset.x;
            frame.origin.y = finger.y - self.grabOffset.y;
            frame = [self.delegate window:self wantsToChangeToRect:frame];
            self.view.frame = frame;
            break;
        }
        case UIGestureRecognizerStateEnded:
        case UIGestureRecognizerStateCancelled:
        case UIGestureRecognizerStateFailed:
            [self updateOriginalFrame];
            [self resizeActionEnd];
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
            
            CGRect corrected = [self.delegate window:self wantsToChangeToRect:proposed];
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
    CGFloat navBarHeight = self.windowBar.frame.size.height;
    
    CGRect frame = self.view.frame;
    frame.origin.y += navBarHeight;
    frame.size.height -= navBarHeight;
    
    [_session windowChangesSizeToRect:frame];
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

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection
{
    [super traitCollectionDidChange:previousTraitCollection];
    
    // Fixes that the color doesnt change when the user changes to dark/light mode
    self.contentStack.layer.borderColor = UIColor.systemGray3Color.CGColor;
}

- (void)dealloc
{
    NSLog(@"deallocated %@", self);
}

@end

