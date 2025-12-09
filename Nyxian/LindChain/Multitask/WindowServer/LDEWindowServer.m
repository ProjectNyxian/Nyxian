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
#import <LindChain/Multitask/WindowServer/LaunchPad/LDEAppLaunchpad.h>
#import <LindChain/Multitask/ProcessManager/LDEProcessManager.h>
#if __has_include(<Nyxian-Swift.h>)
#import <Nyxian-Swift.h>
#endif

static const NSInteger kTagSegmentControl = 5000;
static const NSInteger kTagRunningAppsScrollView = 5001;
static const NSInteger kTagReflection = 9999;
static const NSInteger kTagTitle = 8888;
static const NSInteger kTagShineView = 7777;

@interface LDEWindowServer () <LDEAppLaunchpadDelegate>

@property (nonatomic, strong) UIStackView *stackView;
@property (nonatomic, strong) UIStackView *placeholderStack;
@property (nonatomic, strong) LDEWindow *activeWindow;
@property (nonatomic, assign) wid_t activeWindowIdentifier;
@property (nonatomic, strong) UIScrollView *runningAppsScrollView;
@property (nonatomic, strong) LDEAppLaunchpad *launchpad;
@property (nonatomic, strong) UISegmentedControl *segmentControl;

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
        _launchpad = nil;
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
    if(!window) return;
    
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
    
    if(completion)
    {
        completion();
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
        }
        return;
    }

    [window.view.layer removeAllAnimations];
    
    [UIView animateWithDuration:0.3 animations:^{
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
                LDEWindow *window = [[LDEWindow alloc] initWithSession:session withDelegate:self];
                window.identifier = windowIdentifier;
                
                if(window)
                {
                    weakSelf.windows[@(windowIdentifier)] = window;
                    [self userDidFocusWindow:window];
                    [weakSelf.windowOrder insertObject:@(windowIdentifier) atIndex:0];
                    [self activateWindowForIdentifier:windowIdentifier animated:YES withCompletion:nil];
                }
            }
            else
            {
                return;
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
        if(self.activeWindowIdentifier == identifier)
        {
            self.activeWindowIdentifier = (wid_t)-1;
        }
        
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

// TODO: FRIDA! PLS MAKE LDEWINDOWSERVERTILEVIEW!!!! IM SO LAZY ONG
- (void)handleLongPress:(UILongPressGestureRecognizer *)recognizer
{
    if(_activeWindowIdentifier == (wid_t)-1 &&
       (recognizer.state == UIGestureRecognizerStateBegan || recognizer == nil))
    {
        if(!self.appSwitcherView)
        {
            [self buildAppSwitcherView];
        }

        [self showAppSwitcher];
    }
}

- (void)buildAppSwitcherView
{
    UIView *container = [[UIView alloc] init];
    container.translatesAutoresizingMaskIntoConstraints = NO;
    container.layer.shadowColor = [UIColor blackColor].CGColor;
    container.layer.shadowOpacity = 0.25;
    container.layer.shadowRadius = 12;
    container.layer.shadowOffset = CGSizeMake(0, -4);
    
    UIVisualEffectView *effectView = [self createBlurEffectView];
    effectView.translatesAutoresizingMaskIntoConstraints = NO;
    effectView.layer.cornerRadius = 20;
    effectView.layer.masksToBounds = YES;
    [container addSubview:effectView];
    
    [NSLayoutConstraint activateConstraints:@[
        [effectView.topAnchor constraintEqualToAnchor:container.topAnchor],
        [effectView.bottomAnchor constraintEqualToAnchor:container.bottomAnchor],
        [effectView.leadingAnchor constraintEqualToAnchor:container.leadingAnchor],
        [effectView.trailingAnchor constraintEqualToAnchor:container.trailingAnchor]
    ]];
    
    self.segmentControl = [[UISegmentedControl alloc] initWithItems:@[@"Running", @"All Apps"]];
    self.segmentControl.selectedSegmentIndex = 0;
    self.segmentControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.segmentControl.tag = kTagSegmentControl;
    [self.segmentControl addTarget:self action:@selector(segmentChanged:) forControlEvents:UIControlEventValueChanged];
    [effectView.contentView addSubview:self.segmentControl];
    
    self.runningAppsScrollView = [[UIScrollView alloc] init];
    self.runningAppsScrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.runningAppsScrollView.showsHorizontalScrollIndicator = NO;
    self.runningAppsScrollView.clipsToBounds = NO;
    self.runningAppsScrollView.tag = kTagRunningAppsScrollView;
    [effectView.contentView addSubview:self.runningAppsScrollView];
    
    UIStackView *stack = [[UIStackView alloc] init];
    stack.axis = UILayoutConstraintAxisHorizontal;
    stack.alignment = UIStackViewAlignmentCenter;
    stack.spacing = 20;
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.clipsToBounds = NO;
    self.stackView = stack;
    [self.runningAppsScrollView addSubview:stack];
    
    [self buildPlaceholderStackInView:effectView.contentView];
    
    self.launchpad = [self getOrCreateLaunchpad];
    self.launchpad.translatesAutoresizingMaskIntoConstraints = NO;
    self.launchpad.delegate = self;
    self.launchpad.hidden = YES;
    self.launchpad.alpha = 0;
    [effectView.contentView addSubview:self.launchpad];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.segmentControl.topAnchor constraintEqualToAnchor:effectView.contentView.topAnchor constant:15],
        [self.segmentControl.centerXAnchor constraintEqualToAnchor:effectView.contentView.centerXAnchor],
        [self.segmentControl.widthAnchor constraintEqualToConstant:200],
        [self.segmentControl.heightAnchor constraintEqualToConstant:32],
        
        [self.runningAppsScrollView.topAnchor constraintEqualToAnchor:self.segmentControl.bottomAnchor constant:15],
        [self.runningAppsScrollView.bottomAnchor constraintEqualToAnchor:effectView.contentView.bottomAnchor constant:-20],
        [self.runningAppsScrollView.leadingAnchor constraintEqualToAnchor:effectView.contentView.leadingAnchor],
        [self.runningAppsScrollView.trailingAnchor constraintEqualToAnchor:effectView.contentView.trailingAnchor],
        
        [stack.topAnchor constraintEqualToAnchor:self.runningAppsScrollView.topAnchor],
        [stack.bottomAnchor constraintEqualToAnchor:self.runningAppsScrollView.bottomAnchor],
        [stack.leadingAnchor constraintEqualToAnchor:self.runningAppsScrollView.leadingAnchor constant:20],
        [stack.trailingAnchor constraintEqualToAnchor:self.runningAppsScrollView.trailingAnchor constant:-20],
        [stack.heightAnchor constraintEqualToAnchor:self.runningAppsScrollView.heightAnchor],
        
        [self.launchpad.topAnchor constraintEqualToAnchor:self.segmentControl.bottomAnchor constant:10],
        [self.launchpad.leadingAnchor constraintEqualToAnchor:effectView.contentView.leadingAnchor],
        [self.launchpad.trailingAnchor constraintEqualToAnchor:effectView.contentView.trailingAnchor],
        [self.launchpad.bottomAnchor constraintEqualToAnchor:effectView.contentView.bottomAnchor constant:-10],
    ]];
    
    self.placeholderStack.hidden = (self.windows.count > 0);
    
    [self populateRunningAppTiles];
    
    self.appSwitcherView = container;
    [self.rootViewController.view addSubview:self.appSwitcherView];
    
    [NSLayoutConstraint activateConstraints:@[
        [self.appSwitcherView.leadingAnchor constraintEqualToAnchor:self.rootViewController.view.leadingAnchor],
        [self.appSwitcherView.trailingAnchor constraintEqualToAnchor:self.rootViewController.view.trailingAnchor],
        [self.appSwitcherView.heightAnchor constraintEqualToAnchor:self.rootViewController.view.heightAnchor multiplier:0.55]
    ]];
    
    self.appSwitcherTopConstraint = [self.appSwitcherView.topAnchor constraintEqualToAnchor:self.rootViewController.view.bottomAnchor];
    self.appSwitcherTopConstraint.active = YES;
    [self.rootViewController.view layoutIfNeeded];
    
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePan:)];
    pan.delegate = self;
    [self.appSwitcherView addGestureRecognizer:pan];
    
    self.impactGenerator = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleMedium];
    [self.impactGenerator prepare];
}

- (UIVisualEffectView *)createBlurEffectView
{
    if(@available(iOS 26.0, *))
    {
        UIGlassEffect *glassEffect = [[UIGlassEffect alloc] init];
        return [[UIVisualEffectView alloc] initWithEffect:glassEffect];
    }
    else
    {
        UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
        return [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    }
}

- (void)buildPlaceholderStackInView:(UIView *)parentView
{
    UIImageSymbolConfiguration *config = [UIImageSymbolConfiguration configurationWithPointSize:48 weight:UIImageSymbolWeightRegular];
    UIImage *symbol = [UIImage systemImageNamed:@"app.dashed" withConfiguration:config];
    UIImageView *symbolView = [[UIImageView alloc] initWithImage:symbol];
    symbolView.tintColor = [UIColor secondaryLabelColor];

    UILabel *placeholderLabel = [[UILabel alloc] init];
    placeholderLabel.text = @"No Apps Running";
    placeholderLabel.font = [UIFont systemFontOfSize:16 weight:UIFontWeightSemibold];
    placeholderLabel.textColor = [UIColor secondaryLabelColor];

    UIStackView *placeholderStack = [[UIStackView alloc] initWithArrangedSubviews:@[symbolView, placeholderLabel]];
    placeholderStack.axis = UILayoutConstraintAxisVertical;
    placeholderStack.alignment = UIStackViewAlignmentCenter;
    placeholderStack.spacing = 12;
    placeholderStack.translatesAutoresizingMaskIntoConstraints = NO;
    self.placeholderStack = placeholderStack;

    [parentView addSubview:placeholderStack];
    
    [NSLayoutConstraint activateConstraints:@[
        [placeholderStack.centerXAnchor constraintEqualToAnchor:self.runningAppsScrollView.centerXAnchor],
        [placeholderStack.centerYAnchor constraintEqualToAnchor:self.runningAppsScrollView.centerYAnchor]
    ]];
}

- (void)populateRunningAppTiles
{
    if(self.windows.count == 0)
    {
        return;
    }
    
    for(NSNumber *pidKey in self.windowOrder)
    {
        LDEWindow *window = self.windows[pidKey];
        UIView *tileContainer = [self createTileContainerForWindow:window withKey:pidKey];
        [self.stackView addArrangedSubview:tileContainer];
    }
}

- (UIView *)createTileContainerForWindow:(LDEWindow *)window withKey:(NSNumber *)pidKey
{
    UIView *tileContainer = [[UIView alloc] init];
    tileContainer.translatesAutoresizingMaskIntoConstraints = NO;
    tileContainer.clipsToBounds = NO;
    
    UILabel *title = [[UILabel alloc] init];
    title.translatesAutoresizingMaskIntoConstraints = NO;
    title.text = window.windowName ?: @"App";
    title.font = [UIFont systemFontOfSize:12 weight:UIFontWeightBold];
    title.textAlignment = NSTextAlignmentCenter;
    title.tag = kTagTitle;
    
    UIView *tileWrapper = [[UIView alloc] init];
    tileWrapper.translatesAutoresizingMaskIntoConstraints = NO;
    tileWrapper.clipsToBounds = NO;
    tileWrapper.tag = pidKey.intValue;
    tileWrapper.userInteractionEnabled = YES;
    
    UIVisualEffectView *tileMaterial = [self createTileMaterial];
    tileMaterial.translatesAutoresizingMaskIntoConstraints = NO;
    
    UIImageView *tile = [[UIImageView alloc] init];
    UIImage *snapshot = [window.session snapshotWindow];
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
    [tileContainer addSubview:reflection];
    [tileContainer addSubview:tileWrapper];
    [tileContainer addSubview:title];
    
    [NSLayoutConstraint activateConstraints:@[
        [tileContainer.widthAnchor constraintEqualToConstant:150],
        [tileContainer.heightAnchor constraintEqualToConstant:380],
        
        [title.topAnchor constraintEqualToAnchor:tileContainer.topAnchor],
        [title.centerXAnchor constraintEqualToAnchor:tileContainer.centerXAnchor],
        [title.widthAnchor constraintEqualToConstant:140],
        
        [tileWrapper.topAnchor constraintEqualToAnchor:title.bottomAnchor constant:8],
        [tileWrapper.centerXAnchor constraintEqualToAnchor:tileContainer.centerXAnchor],
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
        
        [reflection.bottomAnchor constraintEqualToAnchor:tileContainer.bottomAnchor],
        [reflection.centerXAnchor constraintEqualToAnchor:tileContainer.centerXAnchor],
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
    
    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTileTap:)];
    [tileWrapper addGestureRecognizer:tap];
    
    UIPanGestureRecognizer *verticalPan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleTileVerticalSwipe:)];
    verticalPan.delegate = self;
    [tileWrapper addGestureRecognizer:verticalPan];
    
    return tileContainer;
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
    return tileMaterial;
}

- (UIView *)createShineView
{
    UIView *shineView = [[UIView alloc] init];
    shineView.translatesAutoresizingMaskIntoConstraints = NO;
    shineView.userInteractionEnabled = NO;
    shineView.layer.cornerRadius = 14;
    shineView.clipsToBounds = YES;
    shineView.tag = kTagShineView;
    
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
    reflection.tag = kTagReflection;
    return reflection;
}

- (void)segmentChanged:(UISegmentedControl*)segment
{
    BOOL showLaunchpad = (segment.selectedSegmentIndex == 1);
    
    [UIView animateWithDuration:0.3
                          delay:0
                        options:UIViewAnimationOptionCurveEaseInOut
                     animations:^{
        self.launchpad.hidden = !showLaunchpad;
        self.launchpad.alpha = showLaunchpad ? 1.0 : 0.0;
        
        self.runningAppsScrollView.hidden = showLaunchpad;
        self.runningAppsScrollView.alpha = showLaunchpad ? 0.0 : 1.0;
        
        self.placeholderStack.hidden = showLaunchpad || (self.windows.count > 0);
        self.placeholderStack.alpha = (showLaunchpad || self.windows.count > 0) ? 0.0 : 1.0;
    } completion:nil];
    
    UIImpactFeedbackGenerator *impact = [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [impact impactOccurred];
}

- (void)launchpadDidSelectAppWithBundleID:(NSString *)bundleID
{
    [self hideAppSwitcher];
    [[LDEProcessManager shared] spawnProcessWithBundleIdentifier:bundleID withKernelSurfaceProcess:kernel_proc_ doRestartIfRunning:NO];
}

- (void)handleTileTap:(UITapGestureRecognizer*)recognizer
{
    UIView *tileWrapper = recognizer.view;
    if(tileWrapper == NULL)
    {
        return;
    }
    
    wid_t identifier = (wid_t)tileWrapper.tag;
    [self activateWindowForIdentifier:identifier animated:YES withCompletion:nil];
}

- (void)handleTileVerticalSwipe:(UIPanGestureRecognizer *)pan
{
    UIView *tileWrapper = pan.view;
    if(!tileWrapper)
    {
        return;
    }
    
    UIView *tileContainer = tileWrapper.superview;
    UIImageView *reflection = [tileContainer viewWithTag:kTagReflection];
    UILabel *title = [tileContainer viewWithTag:kTagTitle];
    UIVisualEffectView *tileMaterial = (UIVisualEffectView *)tileWrapper.subviews.firstObject;
    
    CGPoint translation = [pan translationInView:tileContainer];
    CGPoint velocity = [pan velocityInView:tileContainer];
    
    if(pan.state == UIGestureRecognizerStateChanged)
    {
        [self handleTileSwipeChanged:translation
                            velocity:velocity
                         tileWrapper:tileWrapper
                        tileMaterial:tileMaterial
                               title:title
                          reflection:reflection];
    }
    else if (pan.state == UIGestureRecognizerStateEnded ||
             pan.state == UIGestureRecognizerStateCancelled)
    {
        [self handleTileSwipeEnded:translation
                          velocity:velocity
                       tileWrapper:tileWrapper
                      tileMaterial:tileMaterial
                             title:title
                        reflection:reflection
                     tileContainer:tileContainer];
    }
}

- (void)handleTileSwipeChanged:(CGPoint)translation
                      velocity:(CGPoint)velocity
                   tileWrapper:(UIView*)tileWrapper
                  tileMaterial:(UIVisualEffectView*)tileMaterial
                         title:(UILabel*)title
                    reflection:(UIImageView*)reflection
{
    if(translation.y >= 0)
    {
        return;
    }
    
    CGFloat lift = fabs(translation.y);
    CGFloat maxLift = 250.0;
    CGFloat progress = MIN(1.0, lift / maxLift);
    
    CATransform3D transform = CATransform3DIdentity;
    transform.m34 = -1.0 / 800.0;
    transform = CATransform3DTranslate(transform, 0, translation.y, 0);
    
    CGFloat tiltAngle = progress * 0.4;
    transform = CATransform3DRotate(transform, tiltAngle, 1, 0, 0);
    
    CGFloat maxYRotation = 0.15;
    CGFloat yRotation = (velocity.x / 2000.0) * maxYRotation;
    yRotation = MAX(-maxYRotation, MIN(maxYRotation, yRotation));
    transform = CATransform3DRotate(transform, yRotation, 0, 1, 0);
    
    CGFloat scale = 1.0 - (progress * 0.1);
    transform = CATransform3DScale(transform, scale, scale, scale);
    
    CGFloat zTranslate = -progress * 50;
    transform = CATransform3DTranslate(transform, 0, 0, zTranslate);
    
    CGFloat horizontalDrift = (velocity.x / 1500.0) * 15.0;
    horizontalDrift = MAX(-20, MIN(20, horizontalDrift));
    transform = CATransform3DTranslate(transform, horizontalDrift, 0, 0);
    
    tileWrapper.layer.transform = transform;
    tileWrapper.alpha = 1.0 - (progress * 0.5);
    
    tileMaterial.layer.shadowOpacity = 0.25 + (progress * 0.15);
    tileMaterial.layer.shadowRadius = 12 + (progress * 6);
    tileMaterial.layer.shadowOffset = CGSizeMake(horizontalDrift * 0.2, 6 + (progress * 15));
    
    title.alpha = 1.0 - progress;
    CATransform3D titleTransform = CATransform3DIdentity;
    titleTransform.m34 = -1.0 / 800.0;
    titleTransform = CATransform3DTranslate(titleTransform, horizontalDrift * 0.3, translation.y * 0.25, 0);
    titleTransform = CATransform3DScale(titleTransform, 1.0 - (progress * 0.15), 1.0 - (progress * 0.15), 1);
    title.layer.transform = titleTransform;
    
    CGFloat scaleY = 1.0 + (progress * 0.8);
    reflection.transform = CGAffineTransformConcat(
        CGAffineTransformMakeScale(1, -scaleY),
        CGAffineTransformMakeTranslation(0, lift)
    );
    reflection.alpha = 0.35 * (1.0 - (progress * 0.6));
}

- (void)handleTileSwipeEnded:(CGPoint)translation
                    velocity:(CGPoint)velocity
                 tileWrapper:(UIView*)tileWrapper
                tileMaterial:(UIVisualEffectView *)tileMaterial
                       title:(UILabel*)title
                  reflection:(UIImageView*)reflection
               tileContainer:(UIView *)tileContainer
{
    CGFloat velocityY = velocity.y;
    CGFloat velocityX = velocity.x;
    CGFloat offsetY = translation.y;
    
    BOOL shouldDismiss = (offsetY < -100) || (velocityY < -500);
    
    if(shouldDismiss)
    {
        [self dismissTile:tileWrapper
             tileMaterial:tileMaterial
                    title:title
               reflection:reflection
            tileContainer:tileContainer
                velocityX:velocityX
                  offsetY:offsetY];
    }
    else
    {
        [self resetTile:tileWrapper
           tileMaterial:tileMaterial
                  title:title
             reflection:reflection];
    }
}

- (void)dismissTile:(UIView*)tileWrapper
       tileMaterial:(UIVisualEffectView*)tileMaterial
              title:(UILabel*)title
         reflection:(UIImageView*)reflection
      tileContainer:(UIView*)tileContainer
          velocityX:(CGFloat)velocityX
            offsetY:(CGFloat)offsetY
{
    CGFloat lift = fabs(offsetY);
    CGFloat progress = MIN(1.0, lift / 250.0);
    CGFloat currentScale = 1.0 + (progress * 0.8);
    
    CGFloat exitYRotation = (velocityX / 800.0) * 0.5;
    exitYRotation = MAX(-0.6, MIN(0.6, exitYRotation));
    CGFloat exitDriftX = (velocityX / 800.0) * 100;
    exitDriftX = MAX(-150, MIN(150, exitDriftX));
    
    UIStackView *stack = self.stackView;
    
    [UIView animateWithDuration:0.25
                          delay:0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        CATransform3D exitTransform = CATransform3DIdentity;
        exitTransform.m34 = -1.0 / 600.0;
        exitTransform = CATransform3DTranslate(exitTransform, exitDriftX, -tileContainer.bounds.size.height * 0.8, -200);
        exitTransform = CATransform3DRotate(exitTransform, 0.7, 1, 0, 0);
        exitTransform = CATransform3DRotate(exitTransform, exitYRotation, 0, 1, 0);
        exitTransform = CATransform3DScale(exitTransform, 0.5, 0.5, 0.5);
        tileWrapper.layer.transform = exitTransform;
        tileWrapper.alpha = 0;
        
        tileMaterial.layer.shadowOpacity = 0;
        
        title.alpha = 0;
        CATransform3D titleExit = CATransform3DIdentity;
        titleExit.m34 = -1.0 / 800.0;
        titleExit = CATransform3DTranslate(titleExit, exitDriftX * 0.3, -100, -50);
        titleExit = CATransform3DScale(titleExit, 0.7, 0.7, 1);
        title.layer.transform = titleExit;
        
        reflection.transform = CGAffineTransformConcat(
            CGAffineTransformMakeScale(1, -(currentScale + 0.5)),
            CGAffineTransformMakeTranslation(0, lift + 100)
        );
        reflection.alpha = 0;
    } completion:^(BOOL finished) {
        wid_t identifier = (wid_t)tileWrapper.tag;
        LDEWindow *window = self.windows[@(identifier)];
        
        if(window)
        {
            [window.session closeWindowWithScene:self.windowScene withFrame:window.view.frame];
        }
        
        tileContainer.hidden = YES;
        
        [UIView animateWithDuration:0.35
                              delay:0
             usingSpringWithDamping:0.8
              initialSpringVelocity:0.5
                            options:UIViewAnimationOptionCurveEaseInOut
                         animations:^{
            [stack removeArrangedSubview:tileContainer];
            [tileContainer removeFromSuperview];
            [stack layoutIfNeeded];
            [stack.superview layoutIfNeeded];
        } completion:^(BOOL finished) {
            if (self.windows.count == 0 && self.placeholderStack) {
                self.placeholderStack.alpha = 0;
                self.placeholderStack.hidden = NO;
                [UIView animateWithDuration:0.3 animations:^{
                    self.placeholderStack.alpha = 1;
                }];
            }
        }];
    }];
}

- (void)resetTile:(UIView*)tileWrapper
     tileMaterial:(UIVisualEffectView*)tileMaterial
            title:(UILabel*)title
       reflection:(UIImageView*)reflection
{
    [UIView animateWithDuration:0.7
                          delay:0
         usingSpringWithDamping:0.55
          initialSpringVelocity:0.9
                        options:UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        tileWrapper.layer.transform = CATransform3DIdentity;
        tileWrapper.alpha = 1.0;
        tileMaterial.layer.shadowOpacity = 0.25;
        tileMaterial.layer.shadowRadius = 12;
        tileMaterial.layer.shadowOffset = CGSizeMake(0, 6);
        
        title.alpha = 1.0;
        title.layer.transform = CATransform3DIdentity;
        
        reflection.transform = CGAffineTransformMakeScale(1, -1);
        reflection.alpha = 0.35;
    } completion:nil];
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
    } completion:^(BOOL finished) {
        [self.appSwitcherView removeFromSuperview];
        self.appSwitcherView = nil;
        self.appSwitcherTopConstraint = nil;
        self.placeholderStack = nil;
        self.stackView = nil;
        self.runningAppsScrollView = nil;
        self.segmentControl = nil;
    }];
    
    UIImpactFeedbackGenerator *dismissHaptic = [[UIImpactFeedbackGenerator alloc]
        initWithStyle:UIImpactFeedbackStyleLight];
    [dismissHaptic impactOccurred];
}

- (void)handlePan:(UIPanGestureRecognizer*)pan
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
            } completion:nil];
        }
    }
}

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer
{
    if([gestureRecognizer isKindOfClass:[UIPanGestureRecognizer class]])
    {
        UIPanGestureRecognizer *pan = (UIPanGestureRecognizer *)gestureRecognizer;
        UIView *view = gestureRecognizer.view;
        
        BOOL isTilePan = (view.superview.superview == self.stackView);
        
        if(isTilePan)
        {
            CGPoint velocity = [pan velocityInView:self];
            return (fabs(velocity.y) > fabs(velocity.x)) && (velocity.y < 0);
        }
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

- (CGRect)userDoesChangeWindow:(LDEWindow*)window
                        toRect:(CGRect)rect
{
    UIEdgeInsets insets = self.safeAreaInsets;
    CGRect bounds = self.bounds;
    
    CGRect allowed = CGRectMake(
        bounds.origin.x + insets.left,
        bounds.origin.y + insets.top,
        bounds.size.width - insets.left - insets.right,
        bounds.size.height - insets.top - insets.bottom
    );
    
    if(window.isMaximized)
    {
        allowed.size.height = bounds.size.height - insets.top;
        return allowed;
    }
    
    if(rect.size.width > allowed.size.width)
    {
        rect.size.width = allowed.size.width;
    }
    
    if(rect.size.height > allowed.size.height)
    {
        rect.size.height = allowed.size.height;
    }

    if(rect.origin.x < allowed.origin.x)
    {
        rect.origin.x = allowed.origin.x;
    }
    
    if(CGRectGetMaxX(rect) > CGRectGetMaxX(allowed))
    {
        rect.origin.x = CGRectGetMaxX(allowed) - rect.size.width;
    }
    
    if(rect.origin.y < allowed.origin.y)
    {
        rect.origin.y = allowed.origin.y;
    }
    
    if(CGRectGetMaxY(rect) > CGRectGetMaxY(allowed))
    {
        rect.origin.y = CGRectGetMaxY(allowed) - rect.size.height;
    }
    
    return rect;
}

- (void)orientationChanged:(NSNotification*)notification
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

- (LDEAppLaunchpad*)getOrCreateLaunchpad
{
    if(!self.launchpad)
    {
        self.launchpad = [[LDEAppLaunchpad alloc] init];
        self.launchpad.delegate = self;
    }
    return self.launchpad;
}

@end
