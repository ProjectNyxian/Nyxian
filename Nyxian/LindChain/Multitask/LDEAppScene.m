//
//  AppSceneView.m
//  LiveContainer
//
//  Created by s s on 2025/5/17.
//
#import "LDEAppScene.h"
#import "LDEWindow.h"
#import <LindChain/LiveContainer/LCUtils.h>
#import "Localization.h"
#import <LindChain/ProcEnvironment/Server/Server.h>
#import <LindChain/Private/UIKitPrivate.h>
#import <dlfcn.h>
#import <objc/message.h>
#import <CoreGraphics/CoreGraphics.h>
#import <LindChain/ProcEnvironment/libproc.h>
#import <LindChain/ProcEnvironment/Surface/surface.h>
#import <LindChain/ProcEnvironment/Surface/proc.h>

@interface LDEAppScene()

@property int resizeDebounceToken;
@property CGPoint normalizedOrigin;

@end

@interface LDEAppScene()

@property (nonatomic) UIWindowScene *hostScene;
@property (nonatomic) dispatch_once_t cleanUpOnce;
@property (nonatomic, strong) CADisplayLink *resizeDisplayLink;
@property (nonatomic, strong) NSTimer *resizeEndDebounceTimer;
@property (nonatomic, strong) NSTimer *backgroundEnforcementTimer;
@property (atomic) int resizeEndDebounceRefCnt;

@end

@implementation LDEAppScene

- (instancetype)initWithProcess:(LDEProcess*)process
                   withDelegate:(id<LDEAppSceneDelegate>)delegate;
{
    self = [super initWithNibName:nil bundle:nil];
    self.view = [[UIView alloc] init];
    self.contentView = [[UIView alloc] init];
    [self.view addSubview:_contentView];
    self.delegate = delegate;
    self.scaleRatio = 1.0;
    self.process = process;
    _resizeEndDebounceRefCnt = 0;
    [self setUpAppPresenter];
    return self;
}

- (void)setUpAppPresenter
{
    FBProcessManager *manager = [PrivClass(FBProcessManager) sharedInstance];
    // At this point, the process is spawned and we're ready to create a scene to render in our app
    [manager registerProcessForAuditToken:self.process.processHandle.auditToken];
    self.sceneID = [NSString stringWithFormat:@"sceneID:%@-%@", @"LiveProcess", NSUUID.UUID.UUIDString];
    
    FBSMutableSceneDefinition *definition = [PrivClass(FBSMutableSceneDefinition) definition];
    definition.identity = [PrivClass(FBSSceneIdentity) identityForIdentifier:self.sceneID];
    
    // FIXME: Handle when the process is not valid anymore, it will cause EXC_BREAKPOINT otherwise because of "Invalid condition not satisfying: processIdentity"
    definition.clientIdentity = [PrivClass(FBSSceneClientIdentity) identityForProcessIdentity:self.process.processHandle.identity];
    definition.specification = [UIApplicationSceneSpecification specification];
    FBSMutableSceneParameters *parameters = [PrivClass(FBSMutableSceneParameters) parametersForSpecification:definition.specification];
    
    UIMutableApplicationSceneSettings *settings = [UIMutableApplicationSceneSettings new];
    settings.canShowAlerts = YES;
    settings.cornerRadiusConfiguration = [[PrivClass(BSCornerRadiusConfiguration) alloc] initWithTopLeft:self.view.layer.cornerRadius bottomLeft:self.view.layer.cornerRadius bottomRight:self.view.layer.cornerRadius topRight:self.view.layer.cornerRadius];
    settings.displayConfiguration = UIScreen.mainScreen.displayConfiguration;
    settings.foreground = YES;
    
    settings.deviceOrientation = UIDevice.currentDevice.orientation;
    settings.interfaceOrientation = UIApplication.sharedApplication.statusBarOrientation;
    settings.frame = CGRectMake(0, 0, self.view.frame.size.height, self.view.frame.size.width);
    
    //settings.interruptionPolicy = 2; // reconnect
    settings.level = 1;
    settings.persistenceIdentifier = NSUUID.UUID.UUIDString;
    
    // it seems some apps don't honor these settings so we don't cover the top of the app
    settings.peripheryInsets = UIEdgeInsetsMake(0, 0, 0, 0);
    settings.safeAreaInsetsPortrait = UIEdgeInsetsMake(0, 0, 0, 0);
    
    settings.statusBarDisabled = YES;
    self.settings = settings;
    parameters.settings = settings;
    
    UIMutableApplicationSceneClientSettings *clientSettings = [UIMutableApplicationSceneClientSettings new];
    clientSettings.interfaceOrientation = UIInterfaceOrientationPortrait;
    clientSettings.statusBarStyle = 0;
    parameters.clientSettings = clientSettings;
    
    FBScene *scene = [[PrivClass(FBSceneManager) sharedInstance] createSceneWithDefinition:definition initialParameters:parameters];
    
    self.presenter = [scene.uiPresentationManager createPresenterWithIdentifier:self.sceneID];
    [self.presenter modifyPresentationContext:^(UIMutableScenePresentationContext *context) {
        context.appearanceStyle = 2;
    }];
    
    [self.contentView addSubview:self.presenter.presentationView];
    self.contentView.layer.anchorPoint = CGPointMake(0, 0);
    self.contentView.layer.position = CGPointMake(0, 0);
}

- (void)viewDidMoveToWindow:(UIWindow *)window shouldAppearOrDisappear:(BOOL)appear
{
    [super viewDidMoveToWindow:window shouldAppearOrDisappear:appear];
    [self setForegroundEnabled:(window != nil)];
}

- (void)_performActionsForUIScene:(UIScene *)scene
              withUpdatedFBSScene:(id)fbsScene
                     settingsDiff:(FBSSceneSettingsDiff *)diff
                     fromSettings:(UIApplicationSceneSettings *)settings
                transitionContext:(id)context
              lifecycleActionType:(uint32_t)actionType
{
    if(![self.process.processHandle isValid])
    {
        [self terminationCleanUp];
        return;
    }
    else if(self.process.isSuspended || !diff)
    {
        return;
    }
    
    UIMutableApplicationSceneSettings *baseSettings = [diff settingsByApplyingToMutableCopyOfSettings:settings];
    UIApplicationSceneTransitionContext *newContext = [context copy];
    newContext.actions = nil;
    [self.delegate appSceneVC:self didUpdateFromSettings:baseSettings transitionContext:newContext];
}

- (void)viewWillLayoutSubviews {
    [self startLiveResizeWithSettingsBlock:self.nextUpdateSettingsBlock];
    self.nextUpdateSettingsBlock = nil;
}

- (void)terminationCleanUp
{
    dispatch_once(&_cleanUpOnce, ^{
        void (^cleanupBlock)(void) = ^{
            if (self.sceneID) {
                [[PrivClass(FBSceneManager) sharedInstance] destroyScene:self.sceneID withTransitionContext:nil];
            }
            if (self.presenter) {
                [self.presenter deactivate];
                [self.presenter invalidate];
                self.presenter = nil;
            }
            
            [self.delegate appSceneVCAppDidExit:self];
        };
        
        if ([NSThread isMainThread]) {
            cleanupBlock();
        } else {
            dispatch_sync(dispatch_get_main_queue(), cleanupBlock);
        }
    });
}

- (void)setBackgroundNotificationEnabled:(bool)enabled {
    if(enabled)
        [NSNotificationCenter.defaultCenter addObserver:self.process.extension selector:@selector(_hostDidEnterBackgroundNote:) name:UIApplicationDidEnterBackgroundNotification object:UIApplication.sharedApplication];
    else
        [NSNotificationCenter.defaultCenter removeObserver:self.process.extension name:UIApplicationDidEnterBackgroundNotification object:UIApplication.sharedApplication];
}

- (void)startLiveResizeWithSettingsBlock:(void (^)(UIMutableApplicationSceneSettings *settings))block {
    self.pendingSettingsBlock = block;
    
    if (!self.resizeDisplayLink)
    {
        self.resizeDisplayLink = [CADisplayLink displayLinkWithTarget:self selector:@selector(updateSceneFrame)];
        [self.resizeDisplayLink addToRunLoop:[NSRunLoop mainRunLoop] forMode:NSRunLoopCommonModes];
        self.resizeDisplayLink.paused = YES;
    }
}

- (void)updateSceneFrame
{
    if (!self.presenter || !self.presenter.scene) return;

    CGRect frame = CGRectMake(
        self.view.frame.origin.x,
        self.view.frame.origin.y,
        self.view.frame.size.width / self.scaleRatio,
        self.view.frame.size.height / self.scaleRatio
    );

    [self.presenter.scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
        settings.deviceOrientation = UIDevice.currentDevice.orientation;
        settings.interfaceOrientation = self.view.window.windowScene.interfaceOrientation;

        if (UIInterfaceOrientationIsLandscape(settings.interfaceOrientation)) {
            settings.frame = CGRectMake(frame.origin.x, frame.origin.y, frame.size.height, frame.size.width);
        } else {
            settings.frame = frame;
        }
        if (self.pendingSettingsBlock) {
            self.pendingSettingsBlock(settings);
        }
    }];
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
    self.pendingSettingsBlock = nil;
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

- (void)setForegroundEnabled:(BOOL)foreground
{
    [self.presenter.scene updateSettingsWithBlock:^(UIMutableApplicationSceneSettings *settings) {
        settings.foreground = foreground;
    }];
    
    // TODO: Handle spotify playback for example
    if(foreground)
    {
        [self.presenter activate];
        // Do it like on iOS, remove time window if applicable
        if(self.backgroundEnforcementTimer)
        {
            [self.backgroundEnforcementTimer invalidate];
            self.backgroundEnforcementTimer = nil;
        }
        
        // See if proc object needs to be altered
        kinfo_info_surface_t object = proc_object_for_pid(self.process.pid);
        if(object.force_task_role_override)
        {
            object.force_task_role_override = false;
            proc_object_insert(object);
        }
        
        // Resume if applicable
        [self.process resume];
    }
    else
    {
        [self.process sendSignal:SIGUSR1];
        [self.presenter deactivate];
        
        // Do it like on iOS, give application time window for background tasks
        // TODO: Simulate darwinbg with wakeups and stuff in a certain time frame if the original app registered for it such as push notifications, etc
        self.backgroundEnforcementTimer = [NSTimer scheduledTimerWithTimeInterval:15.0 repeats:NO block:^(NSTimer *sender){
            if(!self.backgroundEnforcementTimer) return;
            if([self.process suspend])
            {
                // On iOS a app that gets suspended gets TASK_DARWINBG_APPLICATION assigned as task role
                kinfo_info_surface_t object = proc_object_for_pid(self.process.pid);
                if(object.real.kp_proc.p_pid == 0) return;
                object.force_task_role_override = true;
                object.task_role_override = TASK_DARWINBG_APPLICATION;
                proc_object_insert(object);
            }
        }];
    }
}

@end
 
