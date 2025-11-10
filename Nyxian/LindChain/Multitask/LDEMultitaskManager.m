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

#import <LindChain/Multitask/LDEMultitaskManager.h>
#import <LindChain/Multitask/LDEProcessManager.h>
#if __has_include(<Nyxian-Swift.h>)
#import <Nyxian-Swift.h>
#endif

@interface LDEMultitaskManager ()

@property (nonatomic, strong) NSMutableDictionary<NSNumber *, LDEWindow *> *windows;

@property (nonatomic, strong) UIStackView *stackView;
@property (nonatomic, strong) UIStackView *placeholderStack;
@property (nonatomic, assign) pid_t activeProcessIdentifier;

@end

@implementation LDEMultitaskManager


- (instancetype)init
{
    static BOOL hasInitialized = NO;
    if (hasInitialized) {
        @throw [NSException exceptionWithName:NSInternalInconsistencyException
                                       reason:@"This class may only be initialized once."
                                     userInfo:nil];
    }
    self = [super initWithFrame:UIScreen.mainScreen.bounds];
    if (self) {
        _windows = [[NSMutableDictionary alloc] init];
        _activeProcessIdentifier = (pid_t)-1;
        hasInitialized = YES;
    }
    return self;
}

+ (instancetype)shared
{
    static LDEMultitaskManager *multitaskManagerSingleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        multitaskManagerSingleton = [[LDEMultitaskManager alloc] init];
    });
    return multitaskManagerSingleton;
}

- (void)deactivateWindowForProcessIdentifier:(pid_t)processIdentifier
                                   pullDown:(BOOL)pullDown
                                 completion:(void (^)(void))completion
{
    LDEWindow *window = self.windows[@(processIdentifier)];
    if (!window || window.view.hidden) { if (completion) completion(); return; }
    
    

    UIView *v = window.view;
    [self bringSubviewToFront:v];

    if (!pullDown) {
        v.hidden = YES;
        v.transform = CGAffineTransformIdentity;
        if (completion) completion();
        return;
    }

    CGFloat h = self.bounds.size.height;
    [v.layer removeAllAnimations];

    [UIView animateWithDuration:0.5
                          delay:0
         usingSpringWithDamping:1.0
          initialSpringVelocity:1.0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        v.transform = CGAffineTransformMakeTranslation(0, h);
        v.alpha = 0.0;
    } completion:^(BOOL finished) {
        v.hidden = YES;
        v.alpha = 1.0;
        v.transform = CGAffineTransformIdentity;
        if (completion) completion();
    }];
}

- (void)activateWindowForProcessIdentifier:(pid_t)processIdentifier animated:(BOOL)animated withCompletion:(void (^)(void))completion {
    LDEWindow *window = self.windows[@(processIdentifier)];
    if (!window) return;
    
    self.activeProcessIdentifier = processIdentifier;

    UIView *v = window.view;
    if (v.superview != self) {
        [self addSubview:v];
    }
    v.hidden = NO;
    [self bringSubviewToFront:v];
    [v.layer removeAllAnimations];
    
    if (animated) {
        v.transform = CGAffineTransformMakeTranslation(0, self.bounds.size.height);
        v.alpha = 1.0;
        [UIView animateWithDuration:0.6
                              delay:0
             usingSpringWithDamping:0.8
              initialSpringVelocity:0.6
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
            v.transform = CGAffineTransformIdentity;
        } completion:^(BOOL done){
            if(done && completion) completion();
        }];
    } else {
        v.transform = CGAffineTransformIdentity;
    }
    
    if (self.appSwitcherView) {
        [self hideAppSwitcher];
    }
}

- (BOOL)openWindowForProcessIdentifier:(pid_t)processIdentifier
{
    __weak typeof(self) weakSelf = self;
    dispatch_async(dispatch_get_main_queue(), ^{
        void (^openAct)(void) = ^{
            LDEWindow *window = [self.windows objectForKey:@(processIdentifier)];
            if(window)
            {
                [weakSelf activateWindowForProcessIdentifier:processIdentifier animated:([[UIDevice currentDevice] userInterfaceIdiom] != UIUserInterfaceIdiomPad) withCompletion:nil];
            }
            else
            {
                LDEProcess *process = [[LDEProcessManager shared] processForProcessIdentifier:processIdentifier];
                if(process)
                {
                    LDEWindow *window = [[LDEWindow alloc] initWithProcess:process withDimensions:CGRectMake(50, 50, 300, 400) dismissalCallback:^{
                        weakSelf.activeProcessIdentifier = (pid_t)-1;
                    }];
                    if(window)
                    {
                        weakSelf.windows[@(processIdentifier)] = window;
                        [weakSelf addSubview:window.view];
                        if (UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone) {
                            if (weakSelf.appSwitcherView) [weakSelf addTileForProcess:processIdentifier window:window];
                            [weakSelf activateWindowForProcessIdentifier:processIdentifier animated:YES withCompletion:^{
                                [self.windowScene _registerSettingsDiffActionArray:@[window.appSceneVC] forKey:window.appSceneVC.sceneID];
                            }];
                        }
                        else
                        {
                            [self.windowScene _registerSettingsDiffActionArray:@[window.appSceneVC] forKey:window.appSceneVC.sceneID];
                        }
                    }
                }
            }
        };
        
        if(weakSelf.activeProcessIdentifier != processIdentifier && [[UIDevice currentDevice] userInterfaceIdiom] != UIUserInterfaceIdiomPad)
        {
            // close first the old one and wait
            [self deactivateWindowForProcessIdentifier:weakSelf.activeProcessIdentifier pullDown:YES completion:^{
                openAct();
            }];
        }
        else
        {
            openAct();
        }
    });
    return YES;
}

- (BOOL)closeWindowForProcessIdentifier:(pid_t)processIdentifier
{
    dispatch_async(dispatch_get_main_queue(), ^{
        LDEWindow *window = self.windows[@(processIdentifier)];
        if(window)
        {
            // If this was the active one, clear active pid
            if (self.activeProcessIdentifier == processIdentifier) {
                self.activeProcessIdentifier = (pid_t)-1;
            }
            [window closeWindow];
            [self.windowScene _unregisterSettingsDiffActionArrayForKey:window.appSceneVC.sceneID];
            [self.windows removeObjectForKey:@(processIdentifier)];
        }
        if(self.appSwitcherView) [self removeTileForProcess:processIdentifier];
    });
    return YES;
}

- (void)addTileForProcess:(pid_t)processIdentifier window:(LDEWindow *)window
{
    if(!self.stackView) return;

    self.placeholderStack.hidden = YES;

    UIView *tile = [[UIView alloc] init];
    tile.translatesAutoresizingMaskIntoConstraints = NO;
    tile.backgroundColor = UIColor.systemBackgroundColor;
    tile.layer.cornerRadius = 16;
    tile.layer.shadowColor = [UIColor blackColor].CGColor;
    tile.layer.shadowOpacity = 0.15;
    tile.layer.shadowRadius = 6;
    tile.layer.shadowOffset = CGSizeMake(0, 3);
    tile.tag = processIdentifier;

    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = window.windowName ?: @"App";
    title.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
    title.textAlignment = NSTextAlignmentCenter;

    [tile addSubview:title];
    [NSLayoutConstraint activateConstraints:@[
        [tile.widthAnchor constraintEqualToConstant:150],
        [tile.heightAnchor constraintEqualToConstant:300],
        [title.centerXAnchor constraintEqualToAnchor:tile.centerXAnchor],
        [title.centerYAnchor constraintEqualToAnchor:tile.centerYAnchor]
    ]];

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTileTap:)];
    [tile addGestureRecognizer:tap];

    UIPanGestureRecognizer *verticalPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleTileVerticalSwipe:)];
    [tile addGestureRecognizer:verticalPan];

    [self.stackView addArrangedSubview:tile];
}

- (void)removeTileForProcess:(pid_t)processIdentifier
{
    if(!self.stackView) return;

    for(UIView *tile in self.stackView.arrangedSubviews)
    {
        if (tile.tag == processIdentifier)
        {
            [self.stackView removeArrangedSubview:tile];
            [tile removeFromSuperview];
            break;
        }
    }

    if(self.stackView.arrangedSubviews.count == 0)
    {
        self.placeholderStack.hidden = NO;
    }
}

- (void)makeKeyAndVisible
{
    [super makeKeyAndVisible];

    if(UIDevice.currentDevice.userInterfaceIdiom == UIUserInterfaceIdiomPhone)
    {
        UILongPressGestureRecognizer *gestureRecognizer = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(handleLongPress:)];
        //gestureRecognizer.numberOfTouchesRequired = 2;
        [self addGestureRecognizer:gestureRecognizer];
    }
}

- (void)handleLongPress:(UILongPressGestureRecognizer *)recognizer
{
    if(_activeProcessIdentifier == -1 && recognizer.state == UIGestureRecognizerStateBegan)
    {
        if(!self.appSwitcherView)
        {
            UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
            UIVisualEffectView *blurView = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
            blurView.translatesAutoresizingMaskIntoConstraints = NO;
            blurView.layer.cornerRadius = 20;
            blurView.layer.masksToBounds = YES;

            UIView *container = [[UIView alloc] init];
            container.translatesAutoresizingMaskIntoConstraints = NO;
            container.layer.shadowColor = [UIColor blackColor].CGColor;
            container.layer.shadowOpacity = 0.25;
            container.layer.shadowRadius = 12;
            container.layer.shadowOffset = CGSizeMake(0, -4);

            [container addSubview:blurView];
            [NSLayoutConstraint activateConstraints:@[
                [blurView.topAnchor constraintEqualToAnchor:container.topAnchor],
                [blurView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
                [blurView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
                [blurView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor]
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
            [blurView.contentView addSubview:scrollView];

            [NSLayoutConstraint activateConstraints:@[
                [scrollView.topAnchor constraintEqualToAnchor:blurView.contentView.topAnchor constant:20],
                [scrollView.bottomAnchor constraintEqualToAnchor:blurView.contentView.bottomAnchor constant:-20],
                [scrollView.leadingAnchor constraintEqualToAnchor:blurView.contentView.leadingAnchor constant:20],
                [scrollView.trailingAnchor constraintEqualToAnchor:blurView.contentView.trailingAnchor constant:-20],
            ]];

            [NSLayoutConstraint activateConstraints:@[
                [stack.topAnchor constraintEqualToAnchor:scrollView.topAnchor],
                [stack.bottomAnchor constraintEqualToAnchor:scrollView.bottomAnchor],
                [stack.leadingAnchor constraintEqualToAnchor:scrollView.leadingAnchor],
                [stack.trailingAnchor constraintEqualToAnchor:scrollView.trailingAnchor],
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

                [blurView.contentView addSubview:placeholderStack];
                [NSLayoutConstraint activateConstraints:@[
                    [placeholderStack.centerXAnchor constraintEqualToAnchor:blurView.contentView.centerXAnchor],
                    [placeholderStack.centerYAnchor constraintEqualToAnchor:blurView.contentView.centerYAnchor]
                ]];
            }

            self.placeholderStack.hidden = (self.windows.count > 0);

            if(self.windows.count > 0)
            {
                for(NSNumber *pidKey in self.windows)
                {
                    LDEWindow *window = self.windows[pidKey];
                    
                    UIView *tile = [[UIView alloc] init];
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
                    title.font = [UIFont systemFontOfSize:14 weight:UIFontWeightMedium];
                    title.textAlignment = NSTextAlignmentCenter;
                    
                    [tile addSubview:title];
                    [NSLayoutConstraint activateConstraints:@[
                        [tile.widthAnchor constraintEqualToConstant:150],
                        [tile.heightAnchor constraintEqualToConstant:300],
                        [title.centerXAnchor constraintEqualToAnchor:tile.centerXAnchor],
                        [title.centerYAnchor constraintEqualToAnchor:tile.centerYAnchor]
                    ]];
                    
                    tile.userInteractionEnabled = YES;
                    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTileTap:)];
                    tile.tag = pidKey.intValue;
                    [tile addGestureRecognizer:tap];
                    
                    UIPanGestureRecognizer *verticalPan = [[UIPanGestureRecognizer alloc] initWithTarget:self
                                                                                                  action:@selector(handleTileVerticalSwipe:)];
                    [tile addGestureRecognizer:verticalPan];
                    
                    [stack addArrangedSubview:tile];
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
                
                if(window)
                {
                    [window.appSceneVC.process terminate];
                }
                [tile removeFromSuperview];
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

    pid_t pid = (pid_t)tile.tag;
    [self activateWindowForProcessIdentifier:pid animated:YES withCompletion:nil];
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

@end
