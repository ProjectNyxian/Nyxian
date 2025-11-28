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

#import <LindChain/Multitask/WindowServer/LDEWindowServer.h>
#if __has_include(<Nyxian-Swift.h>)
#import <Nyxian-Swift.h>
#endif

@interface LDEWindowServer ()

@property (nonatomic, strong) UIStackView *stackView;
@property (nonatomic, strong) UIStackView *placeholderStack;
@property (nonatomic, strong) LDEWindow *activeWindow;
@property (nonatomic, assign) wid_t activeWindowIdentifier;

@end

@implementation LDEWindowServer

- (instancetype)initWithWindowScene:(UIWindowScene *)windowScene
{
    static BOOL hasInitialized = NO;
    if (hasInitialized) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:@"This class may only be initialized once."
                                     userInfo:nil];
    }
    self = [super initWithWindowScene:windowScene];
    if (self) {
        _windows = [[NSMutableDictionary alloc] init];
        _windowOrder = [[NSMutableArray alloc] init];
        _activeWindowIdentifier = (wid_t)-1;
        _appSwitcherView = nil;
        hasInitialized = YES;
    }
    
    [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(orientationChanged:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
    
    return self;
}

+ (instancetype)sharedWithWindowScene:(UIWindowScene*)windowScene
{
    static LDEWindowServer *multitaskManagerSingleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        multitaskManagerSingleton = [[LDEWindowServer alloc] initWithWindowScene:windowScene];
    });
    return multitaskManagerSingleton;
}

+ (instancetype)shared
{
    return [self sharedWithWindowScene:nil];
}

- (wid_t)getNextWindowIdentifier
{
    static wid_t windowIdentifier = 0;
    return windowIdentifier++;
}

- (void)moveWindowToFrontWithNumber:(NSNumber *)number
{
    if (!number || !self.windows[number]) return;

    [self.windowOrder removeObject:number];
    [self.windowOrder insertObject:number atIndex:0];
}

- (void)activateWindowForIdentifier:(wid_t)identifier
                           animated:(BOOL)animated
                     withCompletion:(void (^)(void))completion
{
    LDEWindow *window = self.windows[@(identifier)];
    if (!window) return;
    
    if(window.view.superview != self)
    {
        _activeWindowIdentifier = identifier;
        [self moveWindowToFrontWithNumber:@(identifier)];
        [window.session activateWindow];
        [self addSubview:window.view];
        [window openWindow];
        [window focusWindow];
    }
    
    if(self.appSwitcherView)
    {
        [self hideAppSwitcher];
    }
}

- (void)deactivateWindowByPullDown:(BOOL)pullDown
                    withIdentifier:(wid_t)identifier
                    withCompletion:(void (^)(void))completion
{
    LDEWindow *window = self.windows[@(identifier)];
    if(!window || window.view.hidden)
    {
        if(completion)
        {
            completion();
            return;
        }
    }

    CGFloat h = self.bounds.size.height;
    [window.view.layer removeAllAnimations];

    /*[UIView animateWithDuration:2.0
                          delay:0
         usingSpringWithDamping:1.0
          initialSpringVelocity:1.0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        if(pullDown)
        {
            //window.view.transform = CGAffineTransformMakeTranslation(0, h);
        }
        window.view.alpha = 0.0;
    } completion:^(BOOL finished) {
        window.view.hidden = YES;
        window.view.alpha = 1.0;
        window.view.transform = CGAffineTransformIdentity;
        [window.session deactivateWindow];
        if (completion) completion();
    }];*/
    
    [UIView animateWithDuration:2.0
                     animations:^{
        /*if(pullDown)
        {*/
            //window.view.transform = CGAffineTransformMakeTranslation(0, h);
        //}
        window.view.alpha = 0.0;
    } completion:^(BOOL finished) {
        window.view.hidden = YES;
        window.view.alpha = 1.0;
        window.view.transform = CGAffineTransformIdentity;
        [window.session deactivateWindow];
        if (completion) completion();
    }];
}

- (void)focusWindowForIdentifier:(wid_t)identifier
{
    LDEWindow *window = self.windows[@(identifier)];
    if (!window) return;
    [window focusWindow];
}

- (BOOL)openWindowWithSession:(UIViewController<LDEWindowSession>*)session
                   identifier:(wid_t*)identifier
{
    __block wid_t windowIdentifier = (wid_t)-1;
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        void (^openAct)(void) = ^{
            windowIdentifier = [self getNextWindowIdentifier];
            [session openWindowWithScene:self.windowScene withSessionIdentifier:windowIdentifier];
            LDEWindow *window = [[LDEWindow alloc] initWithSession:session withDelegate:self];
            window.identifier = windowIdentifier;
            if(window)
            {
                weakSelf.windows[@(windowIdentifier)] = window;
                [self userDidFocusWindow:window];
                [weakSelf.windowOrder insertObject:@(windowIdentifier) atIndex:0];
                //[weakSelf addSubview:window.view];
                /*if(UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone)
                {
                    [self activateWindowForIdentifier:windowIdentifier animated:YES withCompletion:nil];
                }
                else
                {
                    // TODO: iPad Stuff Maybe needed
                    [window.session activateWindow];
                }*/
                //[window openWindow];
                [self activateWindowForIdentifier:windowIdentifier animated:YES withCompletion:nil];
            }
        };
        
        LDEWindow *window = self.windows[@(weakSelf.activeWindowIdentifier)];
        if(window != nil &&
           weakSelf.activeWindowIdentifier != window.identifier &&
           [[UIDevice currentDevice] userInterfaceIdiom] != UIUserInterfaceIdiomPad)
        {
            // close first the old one and wait
            [self deactivateWindowByPullDown:YES withIdentifier:weakSelf.activeWindowIdentifier withCompletion:^{
                openAct();
            }];
        }
        else
        {
            openAct();
        }
        
        if(identifier != NULL) *identifier = windowIdentifier;
    });
    return YES;
}

- (BOOL)closeWindowWithIdentifier:(wid_t)identifier
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if(self.activeWindowIdentifier == identifier) self.activeWindowIdentifier = (wid_t)-1;
        LDEWindow *window = self.windows[@(identifier)];
        if(window != nil)
        {
            [window closeWindow];
            [self.windows removeObjectForKey:@(identifier)];
            [self.windowOrder removeObject:@(identifier)];
        }
    });
    return YES;
}

- (void)makeKeyAndVisible
{
    [super makeKeyAndVisible];

    if(UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone)
    {
        if(@available(iOS 26.0, *))
        {
            return;
        }
        
        UILongPressGestureRecognizer *gestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        [self addGestureRecognizer:gestureRecognizer];
    }
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)recognizer
{
    if(_activeWindowIdentifier == (wid_t)-1 && (recognizer.state == UIGestureRecognizerStateBegan || recognizer == nil))
    {
        if(!self.appSwitcherView)
        {
            UIVisualEffectView *effectView;
            if (@available(iOS 26.0, *)) {
                UIGlassEffect *glassEffect = [[UIGlassEffect alloc] init];
                effectView = [[UIVisualEffectView alloc] initWithEffect:glassEffect];
            } else {
                UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
                effectView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
            }
            
            effectView.translatesAutoresizingMaskIntoConstraints = NO;
            effectView.layer.cornerRadius = 20;
            effectView.layer.masksToBounds = YES;

            UIView *container = [[UIView alloc] init];
            container.translatesAutoresizingMaskIntoConstraints = NO;
            container.layer.shadowColor = [UIColor blackColor].CGColor;
            container.layer.shadowOpacity = 0.25;
            container.layer.shadowRadius = 12;
            container.layer.shadowOffset = CGSizeMake(0, -4);

            [container addSubview:effectView];
            [NSLayoutConstraint activateConstraints:@[
                [effectView.topAnchor constraintEqualToAnchor:container.topAnchor],
                [effectView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
                [effectView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
                [effectView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor]
            ]];
            
            UIScrollView *scrollView = [[UIScrollView alloc] init];
            scrollView.translatesAutoresizingMaskIntoConstraints = NO;
            scrollView.showsHorizontalScrollIndicator = NO;

            UIStackView *stack = [[UIStackView alloc] init];
            stack.axis = UILayoutConstraintAxisHorizontal;
            stack.alignment = UIStackViewAlignmentCenter;
            stack.spacing = 20;
            stack.translatesAutoresizingMaskIntoConstraints = NO;
            self.stackView = stack;

            [scrollView addSubview:stack];
            [effectView.contentView addSubview:scrollView];

            [NSLayoutConstraint activateConstraints:@[
                [scrollView.topAnchor constraintEqualToAnchor:effectView.contentView.topAnchor constant:20],
                [scrollView.bottomAnchor constraintEqualToAnchor:effectView.contentView.bottomAnchor constant:-20],
                [scrollView.leadingAnchor constraintEqualToAnchor:effectView.contentView.leadingAnchor],
                [scrollView.trailingAnchor constraintEqualToAnchor:effectView.contentView.trailingAnchor],
            ]];

            [NSLayoutConstraint activateConstraints:@[
                [stack.topAnchor constraintEqualToAnchor:scrollView.topAnchor],
                [stack.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor],
                [stack.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor constant:20],
                [stack.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor constant:-20],
                [stack.heightAnchor constraintEqualToAnchor:scrollView.heightAnchor]
            ]];

            if (!self.placeholderStack)
            {
                UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:48 weight:UIImageSymbolWeightRegular];
                UIImage *symbol = [UIImage systemImageNamed:@"app.dashed" withConfiguration:config];
                UIImageView *symbolView = [[UIImageView alloc] initWithImage:symbol];
                symbolView.tintColor = [UIColor secondaryLabelColor];

                UILabel *placeholderLabel = [[UILabel alloc] init];
                placeholderLabel.text = @"No Apps Launched Yet";
                placeholderLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
                placeholderLabel.textColor = [UIColor secondaryLabelColor];

                UIStackView *placeholderStack = [[UIStackView alloc] initWithArrangedSubviews:@[symbolView, placeholderLabel]];
                placeholderStack.axis = UILayoutConstraintAxisVertical;
                placeholderStack.alignment = UIStackViewAlignmentCenter;
                placeholderStack.spacing = 12;
                placeholderStack.translatesAutoresizingMaskIntoConstraints = NO;
                self.placeholderStack = placeholderStack;

                [effectView.contentView addSubview:placeholderStack];
                [NSLayoutConstraint activateConstraints:@[
                    [placeholderStack.centerXAnchor constraintEqualToAnchor:effectView.contentView.centerXAnchor],
                    [placeholderStack.centerYAnchor constraintEqualToAnchor:effectView.contentView.centerYAnchor]
                ]];
            }

            self.placeholderStack.hidden = (self.windows.count > 0);

            if(self.windows.count > 0)
            {
                for (NSNumber *pidKey in self.windowOrder)
                {
                    LDEWindow *window = self.windows[pidKey];
                    
                    UIView *tileContainer = [[UIView alloc] init];
                    tileContainer.translatesAutoresizingMaskIntoConstraints = NO;
                    
                    UIImageView *tile = [[UIImageView alloc] init];
                    UIImage *snapshot = [window.session snapshotWindow];
                    if(snapshot != nil) tile.image = snapshot;
                    tile.clipsToBounds = YES;
                    tile.translatesAutoresizingMaskIntoConstraints = NO;
                    tile.backgroundColor = UIColor.systemBackgroundColor;
                    tile.layer.cornerRadius = 16;
                    tile.layer.shadowColor = [UIColor blackColor].CGColor;
                    tile.layer.shadowOpacity = 0.15;
                    tile.layer.shadowRadius = 6;
                    tile.layer.shadowOffset = CGSizeMake(0, 3);
                    
                    UILabel *title = [[UILabel alloc] init];
                    title.translatesAutoresizingMaskIntoConstraints = NO;
                    title.text = window.windowName ?: @"App";
                    title.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
                    title.textAlignment = NSTextAlignmentCenter;
                    
                    [tileContainer addSubview:tile];
                    [tileContainer addSubview:title];
                    [NSLayoutConstraint activateConstraints:@[
                        [tileContainer.widthAnchor constraintEqualToConstant:150],
                        [tileContainer.heightAnchor constraintEqualToConstant:320],
                        [tile.widthAnchor constraintEqualToConstant:150],
                        [tile.heightAnchor constraintEqualToConstant:300],
                        [title.centerXAnchor constraintEqualToAnchor:tileContainer.centerXAnchor],
                        [title.bottomAnchor constraintEqualToAnchor:tile.topAnchor constant: -5],
                        [title.widthAnchor constraintEqualToConstant:140]
                    ]];
                    
                    tileContainer.userInteractionEnabled = YES;
                    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTileTap:)];
                    tileContainer.tag = pidKey.intValue;
                    [tileContainer addGestureRecognizer:tap];
                    
                    UIPanGestureRecognizer *verticalPan = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                                                  action:@selector(handleTileVerticalSwipe:)];
                    [tileContainer addGestureRecognizer:verticalPan];
                    verticalPan.delegate = self;
                    
                    [stack addArrangedSubview:tileContainer];
                }
            }

            self.appSwitcherView = container;
            [self addSubview:self.appSwitcherView];

            [NSLayoutConstraint activateConstraints:@[
                [self.appSwitcherView.leadingAnchor constraintEqualToAnchor:self.leadingAnchor],
                [self.appSwitcherView.trailingAnchor constraintEqualToAnchor:self.trailingAnchor],
                [self.appSwitcherView.heightAnchor constraintEqualToAnchor:self.heightAnchor multiplier:0.5]
            ]];

            self.appSwitcherTopConstraint = [self.appSwitcherView.topAnchor constraintEqualToAnchor:self.bottomAnchor];
            self.appSwitcherTopConstraint.active = YES;
            [self layoutIfNeeded];

            UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                                  action:@selector(handlePan:)];
            [self.appSwitcherView addGestureRecognizer:pan];
            pan.delegate = self;

            self.impactGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
            [self.impactGenerator prepare];
        }

        [self showAppSwitcher];
    }
}

- (void)handleTileVerticalSwipe:(UIPanGestureRecognizer *)pan
{
    UIView *tile = pan.view;
    if(!tile) return;
    
    CGPoint translation = [pan translationInView:tile.superview];
    
    if(pan.state == UIGestureRecognizerStateChanged)
    {
        if(translation.y < 0)
        {
            tile.transform = CGAffineTransformMakeTranslation(0, translation.y);
        }
    }
    else if(pan.state == UIGestureRecognizerStateEnded || pan.state == UIGestureRecognizerStateCancelled)
    {
        
        CGFloat velocityY = [pan velocityInView:tile.superview].y;
        CGFloat offsetY = translation.y;
        
        BOOL shouldDismiss = (offsetY < -100) || (velocityY < -500);
        
        if(shouldDismiss)
        {
            [UIView animateWithDuration:0.3
                                  delay:0
                                options:UIViewAnimationOptionCurveEaseIn
                             animations:^{
                tile.transform = CGAffineTransformMakeTranslation(0, -tile.superview.bounds.size.height);
                tile.alpha = 0;
            }
                             completion:^(BOOL finished) {
                pid_t pid = (pid_t)tile.tag;
                LDEWindow *window = self.windows[@(pid)];
                
                if(window) [window.session closeWindowWithScene:self.windowScene withFrame:window.view.frame];
                [tile removeFromSuperview];
                
                if(self.windows.count == 1 && self.placeholderStack)
                {
                    self.placeholderStack.hidden = NO;
                }
            }];
        }
        else
        {
            [UIView animateWithDuration:0.3
                             animations:^{
                tile.transform = CGAffineTransformIdentity;
            }];
        }
    }
}

- (void)handleTileTap:(UITapGestureRecognizer *)recognizer
{
    UIView *tile = recognizer.view;
    if (!tile) return;
    wid_t identifier = (wid_t)tile.tag;
    [self activateWindowForIdentifier:identifier animated:YES withCompletion:nil];
}

- (void)showAppSwitcher
{
    self.appSwitcherTopConstraint.active = NO;
    self.appSwitcherTopConstraint = [self.appSwitcherView.topAnchor constraintEqualToAnchor:self.centerYAnchor];
    self.appSwitcherTopConstraint.active = YES;

    [UIView animateWithDuration:0.6
                          delay:0
         usingSpringWithDamping:0.85
          initialSpringVelocity:0.6
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
                         [self layoutIfNeeded];
                     } completion:nil];

    [self.impactGenerator impactOccurred];
}

- (void)showAppSwitcherExternal
{
    [self handleLongPress:nil];
}

- (void)hideAppSwitcher
{
    self.appSwitcherTopConstraint.active = NO;
    self.appSwitcherTopConstraint = [self.appSwitcherView.topAnchor constraintEqualToAnchor:self.bottomAnchor];
    self.appSwitcherTopConstraint.active = YES;
    
    [UIView animateWithDuration:0.5
                          delay:0
         usingSpringWithDamping:1.0
          initialSpringVelocity:1.0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        [self layoutIfNeeded];
    }
                     completion:^(BOOL finished) {
        [self.appSwitcherView removeFromSuperview];
        self.appSwitcherView = nil;
        self.appSwitcherTopConstraint = nil;
        
        self.placeholderStack = nil;
    }];
    
    UIImpactFeedbackGenerator *dismissHaptic = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [dismissHaptic impactOccurred];
}

- (void)handlePan:(UIPanGestureRecognizer *)pan
{
    CGPoint translation = [pan translationInView:self];
    
    if(pan.state == UIGestureRecognizerStateChanged)
    {
        CGFloat offset = MAX(0, translation.y);
        self.appSwitcherTopConstraint.constant = offset;
        [self layoutIfNeeded];
    }
    else if(pan.state == UIGestureRecognizerStateEnded ||
            pan.state == UIGestureRecognizerStateCancelled)
    {
        
        CGFloat velocityY = [pan velocityInView:self].y;
        CGFloat offset = self.appSwitcherTopConstraint.constant;
        
        if(offset > 100 || velocityY > 500)
        {
            [self hideAppSwitcher];
        }
        else
        {
            self.appSwitcherTopConstraint.constant = 0;
            [UIView animateWithDuration:0.5
                                  delay:0
                 usingSpringWithDamping:0.8
                  initialSpringVelocity:0.7
                                options:UIViewAnimationOptionCurveEaseInOut
                             animations:^{
                [self layoutIfNeeded];
            }
                             completion:nil];
        }
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]] &&
        gestureRecognizer.view.superview == self.stackView)
    {
        UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gestureRecognizer;
        CGPoint velocity = [pan velocityInView:self];
        return fabs(velocity.y) > fabs(velocity.x);
    }

    return YES;
}

- (void)userDidFocusWindow:(LDEWindow *)window
{
    if(_activeWindow != nil &&
       _activeWindow != window)
    {
        [_activeWindow unfocusWindow];
    }
    _activeWindow = window;
}

- (void)userDidCloseWindow:(LDEWindow *)window
{
    if(self.activeWindow == window)
    {
        self.activeWindow = nil;
    }
    [self.windows removeObjectForKey:@(window.identifier)];
    [self.windowOrder removeObject:@(window.identifier)];
}

- (void)userDidMinimizeWindow:(LDEWindow*)window
{
    _activeWindowIdentifier = (wid_t)-1;
}

- (CGRect)userDoesChangeWindow:(LDEWindow *)window
                        toRect:(CGRect)rect
{
    UIEdgeInsets insets = self.safeAreaInsets;
    CGRect bounds = self.bounds;
    
    CGRect allowed = CGRectMake(bounds.origin.x + insets.left,
                                bounds.origin.y + insets.top,
                                bounds.size.width  - insets.left - insets.right,
                                bounds.size.height - insets.top - insets.bottom);
    
    if(window.isMaximized)
    {
        allowed.size.height = bounds.size.height - insets.top;
        return allowed;
    }
    
    if (rect.size.width > allowed.size.width)
        rect.size.width = allowed.size.width;
    
    if (rect.size.height > allowed.size.height)
        rect.size.height = allowed.size.height;

    if (rect.origin.x < allowed.origin.x)
        rect.origin.x = allowed.origin.x;
    
    if (CGRectGetMaxX(rect) > CGRectGetMaxX(allowed))
        rect.origin.x = CGRectGetMaxX(allowed) - rect.size.width;
    
    if (rect.origin.y < allowed.origin.y)
        rect.origin.y = allowed.origin.y;
    
    if (CGRectGetMaxY(rect) > CGRectGetMaxY(allowed))
        rect.origin.y = CGRectGetMaxY(allowed) - rect.size.height;
    
    return rect;
}

- (void)orientationChanged:(NSNotification *)notification
{
    dispatch_async(dispatch_get_main_queue(), ^{
        for(NSNumber *key in self.windows)
        {
            LDEWindow *window = self.windows[key];
            if(window != nil)
            {
                [window changeWindowToRect:[self userDoesChangeWindow:window toRect:window.view.frame]];
            }
        }
    });
}

@end

