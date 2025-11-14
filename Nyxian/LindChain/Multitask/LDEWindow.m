#import "LDEWindow.h"
#import "ResizeHandleView.h"
//#import "LiveContainerSwiftUI-Swift.h"
#import "LDEAppScene.h"
#import <LindChain/Private/UIKitPrivate.h>
#import "../LiveContainer/Localization.h"
#import "utils.h"
#import <objc/runtime.h>
#import <LindChain/Multitask/LDEMultitaskManager.h>
#import <LindChain/ProcEnvironment/Server/Server.h>
#import <LindChain/Debugger/Logger.h>

// TODO: Move those away
@implementation RBSTarget(hook)

+ (instancetype)hook_targetWithPid:(pid_t)pid environmentIdentifier:(NSString *)environmentIdentifier
{
    if([environmentIdentifier containsString:@"LiveProcess"]) {
        environmentIdentifier = [NSString stringWithFormat:@"LiveProcess:%d", pid];
    }
    return [self hook_targetWithPid:pid environmentIdentifier:environmentIdentifier];
}

@end

static int hook_return_2(void)
{
    return 2;
}

@interface LDEWindow ()

@property (nonatomic) NSArray* activatedVerticalConstraints;
@property (nonatomic) UIBarButtonItem *maximizeButton;
@property (nonatomic) dispatch_once_t appearOnceAction;

@property (nonatomic, strong) CADisplayLink *resizeDisplayLink;
@property (nonatomic, strong) NSTimer *resizeEndDebounceTimer;
@property (atomic) int resizeEndDebounceRefCnt;

/*@property (nonatomic) CGRect originalFrame;
@property (nonatomic) UIBarButtonItem *maximizeButton;
@property (nonatomic) dispatch_once_t closeWindowOnce;*/

@property (nonatomic) void (^dismissalCallback)(void);

@end

@implementation LDEWindow

- (instancetype)initWithSession:(UIViewController<LDEWindowSession>*)session
              dismissalCallback:(void (^)(void))dismissalCallback
{
    self = [super initWithNibName:nil bundle:nil];
    _session = session;
    _dismissalCallback = dismissalCallback;
    _windowName = session.windowName;
    
    [self setupDecoratedView:CGRectMake(50, 50, 400, 400)];
    
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
        self.navigationItem.rightBarButtonItems = barButtonItems;
    }
    
    return self;
}

- (void)closeWindow
{
    self.dismissalCallback();
}

- (void)dismissViewControllerAnimated:(BOOL)flag
                           completion:(void (^)(void))completion
{
    [super dismissViewControllerAnimated:flag completion:completion];
    _dismissalCallback();
}

/*- (instancetype)initWithProcess:(LDEProcess*)process
                 withDimensions:(CGRect)rect
              dismissalCallback:(void (^)(void))dismissalCallback
{
    self = [super initWithNibName:nil bundle:nil];
    _dismissalCallback = dismissalCallback;
    _appSceneVC = [[LDEAppScene alloc] initWithProcess:process withDelegate:self];
    if(!_appSceneVC) return nil;
    _multitaskingTermination = NO;
    
    [self setupDecoratedView:rect];
    self.scaleRatio = 1.0;
    self.isMaximized = NO;
    self.originalFrame = CGRectZero;
    
    //TODO: Take window name from future process API
    self.windowName = process.displayName;
    self.navigationItem.title = process.displayName;
    
    if([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
    {
        NSArray *menuItems = @[
            [UIAction actionWithTitle:@"Copy Pid" image:[UIImage systemImageNamed:@"doc.on.doc"] identifier:nil handler:^(UIAction * _Nonnull action) {
                UIPasteboard.generalPasteboard.string = @(self.appSceneVC.process.pid).stringValue;
            }],
            [UICustomViewMenuElement elementWithViewProvider:^UIView *(UICustomViewMenuElement *element) {
                return [self scaleSliderViewWithTitle:@"Scale" min:0.5 max:2.0 value:self.scaleRatio stepInterval:0.01];
            }]
        ];
        
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
        
        __weak typeof(self) weakSelf = self;
        [self.navigationItem setTitleMenuProvider:^UIMenu *(NSArray<UIMenuElement *> *suggestedActions){
            NSString *pidText = [NSString stringWithFormat:@"PID: %d", weakSelf.appSceneVC.process.pid];
            return [UIMenu menuWithTitle:pidText children:menuItems];
        }];
    }
    
    return self;
}

- (void)handlePullDown:(UIPanGestureRecognizer *)gesture
{
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
                        [self.appSceneVC setForegroundEnabled:NO];
                        if(self.dismissalCallback != nil) self.dismissalCallback();
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
}*/

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    dispatch_once(&_appearOnceAction, ^{
        [self adjustNavigationBarButtonSpacingWithNegativeSpacing:-8.0 rightMargin:8.0];
        
        // MARK: Suppose to only run on phones
        if([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone)
        {
            [self maximizeWindow:NO];
            UIPanGestureRecognizer *pullDownGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handlePullDown:)];
            [self.navigationBar addGestureRecognizer:pullDownGesture];
        }
        else
        {
            // MARK: Triggering resize system at start to guarantee that it gets layouted
            [self startLiveResizeWithSettingsBlock];
            [self resizeActionStart];
            [self resizeActionEnd];
        }
    });
}

- (void)setupDecoratedView:(CGRect)dimensions
{
    CGFloat navBarHeight = 44;
    self.view = [UIStackView new];
    
    dimensions.size.height += navBarHeight;
    self.view.frame = dimensions;
    
    // Navigation bar
    UINavigationBar *navigationBar = [[UINavigationBar alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, navBarHeight)];
    navigationBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    UINavigationItem *navigationItem = [[UINavigationItem alloc] initWithTitle:_windowName];
    navigationBar.items = @[navigationItem];
    
    self.view.axis = UILayoutConstraintAxisVertical;
    self.view.backgroundColor = UIColor.systemBackgroundColor;
    self.view.layer.cornerRadius = 10;
    self.view.layer.masksToBounds = YES;

    self.navigationBar = navigationBar;
    self.navigationItem = navigationBar.items.firstObject;
    if (!self.navigationBar.superview) {
        [self.view addArrangedSubview:self.navigationBar];
    }
    
    CGRect contentFrame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height - navBarHeight);
    UIView *fixedPositionContentView = [[UIView alloc] initWithFrame:contentFrame];
    self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.view addArrangedSubview:fixedPositionContentView];
    [self.view sendSubviewToBack:fixedPositionContentView];
    
    self.contentView = [[UIView alloc] initWithFrame:contentFrame];
    self.contentView.layer.anchorPoint = self.contentView.layer.position = CGPointMake(0, 0);
    self.contentView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [fixedPositionContentView addSubview:self.contentView];
    
    UIPanGestureRecognizer *moveGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(moveWindow:)];
    moveGesture.minimumNumberOfTouches = 1;
    moveGesture.maximumNumberOfTouches = 1;
    [self.navigationBar addGestureRecognizer:moveGesture];

    // Resize handle (idea stolen from Notes debugging window)
    UIPanGestureRecognizer *resizeGesture = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(resizeWindow:)];
    resizeGesture.minimumNumberOfTouches = 1;
    resizeGesture.maximumNumberOfTouches = 1;
    self.resizeHandle = [[ResizeHandleView alloc] initWithFrame:CGRectMake(self.view.frame.size.width - navBarHeight, self.view.frame.size.height - navBarHeight, navBarHeight, navBarHeight)];
    [self.resizeHandle addGestureRecognizer:resizeGesture];
    [self.view addSubview:self.resizeHandle];
    
    self.view.layer.borderWidth = 0.5;
    self.view.layer.borderColor = UIColor.systemGray3Color.CGColor;
    

    [self addChildViewController:_session];
    [self.view insertSubview:_session.view atIndex:0];
    _session.view.translatesAutoresizingMaskIntoConstraints = NO;
        
    [self updateVerticalConstraints];
    [NSLayoutConstraint activateConstraints:@[
        [_session.view.topAnchor constraintEqualToAnchor:self.view.topAnchor constant:navBarHeight],
        [_session.view.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor]
    ]];
    
    [self updateOriginalFrame];
}


// Stolen from UIKitester
/*- (UIView *)scaleSliderViewWithTitle:(NSString *)title min:(CGFloat)minValue max:(CGFloat)maxValue value:(CGFloat)initialValue stepInterval:(CGFloat)step {
    UIView *containerView = [[UIView alloc] init];
    containerView.translatesAutoresizingMaskIntoConstraints = NO;
    containerView.exclusiveTouch = YES;

    UIStackView *stackView = [[UIStackView alloc] init];
    stackView.axis = UILayoutConstraintAxisVertical;
    stackView.spacing = 0.0;
    stackView.translatesAutoresizingMaskIntoConstraints = NO;
    [containerView addSubview:stackView];
    
    [NSLayoutConstraint activateConstraints:@[
        [stackView.topAnchor constraintEqualToAnchor:containerView.topAnchor constant:10.0],
        [stackView.bottomAnchor constraintEqualToAnchor:containerView.bottomAnchor constant:-8.0],
        [stackView.leadingAnchor constraintEqualToAnchor:containerView.leadingAnchor constant:16.0],
        [stackView.trailingAnchor constraintEqualToAnchor:containerView.trailingAnchor constant:-16.0]
    ]];
    
    UILabel *label = [[UILabel alloc] init];
    label.text = title;
    label.translatesAutoresizingMaskIntoConstraints = NO;
    label.font = [UIFont boldSystemFontOfSize:12.0];
    [stackView addArrangedSubview:label];
    
    _UIPrototypingMenuSlider *slider = [[_UIPrototypingMenuSlider alloc] init];
    slider.minimumValue = minValue;
    slider.maximumValue = maxValue;
    slider.value = initialValue;
    slider.stepSize = step;
    
    NSLayoutConstraint *sliderHeight = [slider.heightAnchor constraintEqualToConstant:40.0];
    sliderHeight.active = YES;
    
    [stackView addArrangedSubview:slider];
    
    [slider addTarget:self action:@selector(scaleSliderChanged:) forControlEvents:UIControlEventValueChanged];
    
    return containerView;
}

- (void)scaleSliderChanged:(_UIPrototypingMenuSlider *)slider {
    self.scaleRatio = slider.value;
    self.appSceneVC.scaleRatio = _scaleRatio;
    self.appSceneVC.contentView.layer.sublayerTransform = CATransform3DMakeScale(_scaleRatio, _scaleRatio, 1.0);
    [self.appSceneVC resizeActionStart];
    [self updateMaximizedSafeAreaWithSettings:self.appSceneVC.settings];
    [self.appSceneVC resizeActionEnd];
}

- (void)closeWindow
{
    dispatch_once(&_closeWindowOnce, ^{
        if([self.appSceneVC.process.processHandle isValid]) [self.appSceneVC.process terminate];
        self.view.layer.masksToBounds = NO;
        [UIView transitionWithView:self.view.window
                          duration:0.2
                           options:UIViewAnimationOptionTransitionCrossDissolve
                        animations:^
         {
            self.view.alpha = 0;
        } completion:^(BOOL completed)
         {
            if(completed) [self.view removeFromSuperview];
        }];
    });
}*/

- (void)maximizeWindow:(BOOL)animated {
    /*[self.appSceneVC resizeActionStart];
    if (self.isMaximized) {
        CGRect maxFrame = UIEdgeInsetsInsetRect(self.view.window.frame, self.view.window.safeAreaInsets);
        CGRect newFrame = CGRectMake(self.originalFrame.origin.x * maxFrame.size.width, self.originalFrame.origin.y * maxFrame.size.height, self.originalFrame.size.width, self.originalFrame.size.height);
        [UIView animateWithDuration:animated ? 0.3 : 0.0 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.view.frame = newFrame;
            self.view.layer.borderWidth = 1;
            self.resizeHandle.alpha = 1;
            if(self.appSceneVC)
            {
                [self.appSceneVC.presenter.scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
                    [self updateWindowedFrameWithSettings:settings];
                }];
            }
        } completion:^(BOOL finished) {
            self.isMaximized = NO;
            UIImage *maximizeImage = [UIImage systemImageNamed:@"arrow.up.left.and.arrow.down.right.circle.fill"];
            UIImageConfiguration *maximizeConfig = [UIImageSymbolConfiguration configurationWithPointSize:16.0 weight:UIImageSymbolWeightMedium];
            self.maximizeButton.image = [maximizeImage imageWithConfiguration:maximizeConfig];
            if(self.appSceneVC)
            {
                [self.appSceneVC resizeActionEnd];
            }
        }];
    } else {
        [self.view.superview bringSubviewToFront:self.view];
        [self updateOriginalFrame];
        [UIView animateWithDuration:animated ? 0.3 : 0.0 delay:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
            self.isMaximized = YES;
            [self updateVerticalConstraints];
            
            self.view.layer.borderWidth = 0;
            self.resizeHandle.alpha = 0;
            if(self.appSceneVC)
            {
                [self.appSceneVC.presenter.scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
                    [self updateMaximizedFrameWithSettings:settings];
                }];
            }
        } completion:^(BOOL finished) {
            UIImage *restoreImage = [UIImage systemImageNamed:@"arrow.down.right.and.arrow.up.left.circle.fill"];
            UIImageConfiguration *restoreConfig = [UIImageSymbolConfiguration configurationWithPointSize:16.0 weight:UIImageSymbolWeightMedium];
            self.maximizeButton.image = [restoreImage imageWithConfiguration:restoreConfig];
            
            if(self.appSceneVC)
            {
                [self.appSceneVC resizeActionEnd];
            }
        }];
    }*/
}

- (void)maximizeButtonPressed
{
    [self maximizeWindow:YES];
}

/*- (void)appSceneVC:(LDEAppScene*)vc didInitializeWithError:(NSError *)error {
    // TODO: Fix it
    dispatch_async(dispatch_get_main_queue(), ^{
        if(error) {
            //[vc appTerminationCleanUp:NO];
            UIAlertController *alert = [UIAlertController alertControllerWithTitle:@"lc.common.error".loc message:error.localizedDescription preferredStyle:UIAlertControllerStyleAlert];
            [alert addAction:[UIAlertAction actionWithTitle:@"lc.common.ok".loc style:UIAlertActionStyleCancel handler:nil]];
            [alert addAction:[UIAlertAction actionWithTitle:@"lc.common.copy".loc style:UIAlertActionStyleDefault handler:^(UIAlertAction * _Nonnull action) {
                UIPasteboard.generalPasteboard.string = error.localizedDescription;
            }]];
            [self presentViewController:alert animated:YES completion:nil];
        } else {
            [self updateOriginalFrame];
        }
    });
}

- (void)appSceneVC:(LDEAppScene*)vc didUpdateFromSettings:(UIMutableApplicationSceneSettings *)baseSettings transitionContext:(id)newContext
{
    UIMutableApplicationSceneSettings *newSettings = [vc.presenter.scene.settings mutableCopy];
    newSettings.userInterfaceStyle = baseSettings.userInterfaceStyle;
    newSettings.interfaceOrientation = baseSettings.interfaceOrientation;
    newSettings.deviceOrientation = baseSettings.deviceOrientation;
        
    [self.appSceneVC resizeActionStart];
    [self.appSceneVC resizeActionEnd];
    
    [_appSceneVC.presenter.scene updateSettings:newSettings withTransitionContext:newContext completion:nil];
}

- (void)appSceneVCAppDidExit:(LDEAppScene*)vc
{
    // TODO: Cleanup these methods they have no need in Nyxians app lifecycle design
}*/

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


/*- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if(_isMaximized) {
        [self.appSceneVC.presenter.scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
            [self updateMaximizedFrameWithSettings:settings];
        }];
    }
    
    BOOL bottomWindowBar = [change[NSKeyValueChangeNewKey] boolValue];
    [UIView animateWithDuration:0.3 animations:^{
        if(bottomWindowBar) {
            self.navigationItem.leftBarButtonItems = self.navigationItem.rightBarButtonItems;
            self.navigationItem.rightBarButtonItems = nil;
            [self.view addArrangedSubview:self.navigationBar];
        } else {
            self.navigationItem.rightBarButtonItems = self.navigationItem.leftBarButtonItems;
            self.navigationItem.leftBarButtonItems = nil;
            [self.view insertArrangedSubview:self.navigationBar atIndex:0];
        }
        
        [self updateVerticalConstraints];
        [self adjustNavigationBarButtonSpacingWithNegativeSpacing:-8.0 rightMargin:-4.0];
    }];
}*/

- (void)moveWindow:(UIPanGestureRecognizer*)sender {
    if(_isMaximized) return;
    
    CGPoint point = [sender translationInView:self.view];
    [sender setTranslation:CGPointZero inView:self.view];
    
    self.view.center = CGPointMake(self.view.center.x + point.x, self.view.center.y + point.y);
    [self updateOriginalFrame];
}

- (void)resizeWindow:(UIPanGestureRecognizer*)gesture
{
    if(_isMaximized) return;
    
    switch (gesture.state) {
        case UIGestureRecognizerStateBegan:
            [self resizeActionStart];
            break;
        case UIGestureRecognizerStateChanged: {
            CGPoint point = [gesture translationInView:self.view];
            [gesture setTranslation:CGPointZero inView:self.view];
            CGRect frame = self.view.frame;
            frame.size.width = MAX(50, frame.size.width + point.x);
            frame.size.height = MAX(50, frame.size.height + point.y);
            self.view.frame = frame;
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
    CGRect frame = CGRectMake(self.view.frame.origin.x,
                              self.view.frame.origin.y + 44,
                              self.view.frame.size.width,
                              self.view.frame.size.height - 44);
    
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
