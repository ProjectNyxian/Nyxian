#import <UIKit/UIKit.h>

@interface UIImage(private)
- (UIImage *)_imageWithSize:(CGSize)size;
@end

@interface UIAlertAction(private)
@property(nonatomic, copy) id shouldDismissHandler;
@end

@interface UIActivityContinuationManager : UIResponder
- (NSDictionary*)handleActivityContinuation:(NSDictionary*)activityDict isSuspended:(id)isSuspended;
@end

@interface UIApplication(private)
- (void)suspend;
- (UIActivityContinuationManager*)_getActivityContinuationManager;
@end

@interface UIContextMenuInteraction(private)
- (void)_presentMenuAtLocation:(CGPoint)location;
@end

@interface _UIContextMenuStyle : NSObject <NSCopying>
@property(nonatomic) NSInteger preferredLayout;
+ (instancetype)defaultStyle;
@end

@interface UIOpenURLAction : NSObject
- (NSURL *)url;
- (instancetype)initWithURL:(NSURL *)arg1;
@end

@interface FBSSceneTransitionContext : NSObject
@property (nonatomic,copy) NSSet * actions;
@end

@interface UIApplicationSceneTransitionContext : FBSSceneTransitionContext
@property (nonatomic,retain) NSDictionary * payload;
@end

@interface UITableViewHeaderFooterView(private)
- (void)setText:(NSString *)text;
- (NSString *)text;
@end

@interface UIApplicationSceneSettings : NSObject
@end

@interface UIApplicationSceneClientSettings : NSObject
@end

@interface UIMutableApplicationSceneSettings : UIApplicationSceneSettings
@property (assign,nonatomic) UIDeviceOrientation deviceOrientation;
- (void)setInterfaceOrientation:(NSInteger)o;
@end



@interface UIMutableApplicationSceneClientSettings : UIApplicationSceneClientSettings
@property (assign,nonatomic) UIDeviceOrientation deviceOrientation;
@property(nonatomic, assign) NSInteger interfaceOrientation;
@property(nonatomic, assign) NSInteger statusBarStyle;
@end


@interface FBSSceneParameters : NSObject
@property(nonatomic, copy) UIApplicationSceneSettings *settings;
@property(nonatomic, copy) UIApplicationSceneClientSettings *clientSettings;
- (instancetype)initWithXPCDictionary:(NSDictionary*)dict;
@end

@interface FBSMutableSceneParameters : FBSSceneParameters
@property(nonatomic, copy) UIMutableApplicationSceneSettings *settings;
@end

@interface UIWindow (private)
- (void)setAutorotates:(BOOL)autorotates forceUpdateInterfaceOrientation:(BOOL)force;
@end

@class LSApplicationProxy;

@interface LSApplicationWorkspace : NSObject
+ (instancetype)defaultWorkspace;
- (BOOL)openApplicationWithBundleID:(NSString *)arg1;
- (NSArray<LSApplicationProxy*>*)allInstalledApplications;
@end

@interface UICustomViewMenuElement : UIMenuElement
+ (instancetype)elementWithViewProvider:(UIView *(^)(UICustomViewMenuElement *element))provider;

@end

@interface UINavigationBar(private)
- (UIFont *)_defaultTitleFont;
@end

@interface _UIPrototypingMenuSlider : UISlider
@property(nonatomic, assign, readwrite) CGFloat stepSize;
@end

@interface UISceneActivationRequestOptions(private)
-(void)_setRequestFullscreen:(BOOL)arg1;
@end

@interface _UIButtonBarStackView : UIView
- (void)setSpacing:(CGFloat)spacing;
@end

@interface UIView(private)
- (UIViewController *)_viewControllerForAncestor;
@end


@interface DOCConfiguration : NSObject
- (void)setHostIdentifier:(NSString *)ignored;
@end

#define PrivClass(NAME) NSClassFromString(@#NAME)

@interface LSResourceProxy : NSObject
    @property (setter=_setLocalizedName:,nonatomic,copy) NSString *localizedName;
@end

@interface LSBundleProxy : LSResourceProxy
@end

@interface LSApplicationProxy : LSBundleProxy
    @property(nonatomic, assign, readonly) NSString *bundleIdentifier;
    @property(nonatomic, assign, readonly) NSString *localizedShortName;
    @property(nonatomic, assign, readonly) NSString *primaryIconName;

    @property (nonatomic,readonly) NSString * applicationIdentifier;
    @property (nonatomic,readonly) NSString * applicationType;
    @property (nonatomic,readonly) NSArray * appTags;
    @property (getter=isLaunchProhibited,nonatomic,readonly) BOOL launchProhibited;
    @property (getter=isPlaceholder,nonatomic,readonly) BOOL placeholder;
    @property (getter=isRemovedSystemApp,nonatomic,readonly) BOOL removedSystemApp;
@end

@interface BSCornerRadiusConfiguration : NSObject
- (id)initWithTopLeft:(CGFloat)tl bottomLeft:(CGFloat)bl bottomRight:(CGFloat)br topRight:(CGFloat)tr;
@end

// BoardServices
@interface BSSettings : NSObject
@end

@interface BSTransaction : NSObject
- (void)addChildTransaction:(id)transaction;
- (void)begin;
- (void)setCompletionBlock:(dispatch_block_t)block;
@end

// FrontBoard

@class RBSProcessIdentity, FBProcessExecutableSlice, UIMutableApplicationSceneClientSettings, UIMutableScenePresentationContext, UIScenePresentationManager, _UIScenePresenter;

@interface FBApplicationProcessLaunchTransaction : BSTransaction
- (instancetype) initWithProcessIdentity:(RBSProcessIdentity *)identity executionContextProvider:(id)providerBlock;
- (void)_begin;
@end

@interface FBProcessExecutionContext : NSObject
@end

@interface FBMutableProcessExecutionContext : FBProcessExecutionContext

@property (nonatomic,copy) RBSProcessIdentity * identity;
@property (nonatomic,copy) NSArray * arguments;
@property (nonatomic,copy) NSDictionary * environment;
@property (nonatomic,retain) NSURL * standardOutputURL;
@property (nonatomic,retain) NSURL * standardErrorURL;
@property (assign,nonatomic) BOOL waitForDebugger;
@property (assign,nonatomic) BOOL disableASLR;
@property (assign,nonatomic) BOOL checkForLeaks;
@property (assign,nonatomic) long long launchIntent;
//@property (nonatomic,retain) id<FBProcessWatchdogProviding> watchdogProvider;
@property (nonatomic,copy) NSString * overrideExecutablePath;
//@property (nonatomic,retain) FBProcessExecutableSlice * overrideExecutableSlice;
@property (nonatomic,copy) id completion;
-(id)copyWithZone:(NSZone*)arg1 ;
@end

@interface FBProcess : NSObject
- (id)name;
@end

@class FBScene;

/* Generated by RuntimeBrowser
   Image: /System/Library/PrivateFrameworks/FrontBoardServices.framework/FrontBoardServices
 */

@interface FBSMutableSceneSettings : NSObject

@end

@interface FBSSceneUpdate : NSObject

// Image: /System/Library/PrivateFrameworks/FrontBoardServices.framework/FrontBoardServices

- (void)inspect:(id /* block */)arg1;
- (id)mutableSettings;
- (id)parentUpdate;
- (id)previousSettings;
- (id)settings;
- (id)settingsDiff;
- (id)transitionContext;

// Image: /System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore

- (void)inspectStorage:(id /* block */)arg1;

@end

@interface FBSceneClientHandle : NSObject
@end

@interface FBSceneUpdateContext : NSObject
@end

@interface FBSSceneClientSettingsDiff : NSObject
@end

@interface FBSSceneClientSettings : NSObject
@end

@protocol FBSceneObserver <NSObject>

@optional

- (void)scene:(FBScene *)arg1 clientDidConnect:(FBSceneClientHandle *)arg2;
- (void)scene:(FBScene *)arg1 didApplyUpdateWithContext:(FBSceneUpdateContext *)arg2;
- (void)scene:(FBScene *)arg1 didCompleteUpdateWithContext:(FBSceneUpdateContext *)arg2 error:(NSError *)arg3;
- (void)scene:(FBScene *)arg1 didPrepareUpdateWithContext:(FBSceneUpdateContext *)arg2;
- (void)scene:(FBScene *)arg1 didUpdateClientSettings:(FBSSceneUpdate *)arg2;
- (void)scene:(FBScene *)arg1 didUpdateClientSettingsWithDiff:(FBSSceneClientSettingsDiff *)arg2 oldClientSettings:(FBSSceneClientSettings *)arg3 transitionContext:(FBSSceneTransitionContext *)arg4;
- (void)scene:(FBScene *)arg1 didUpdateSettings:(FBSSceneUpdate *)arg2;
- (NSSet *)scene:(FBScene *)arg1 handleActions:(NSSet *)arg2;
- (void)sceneContentStateDidChange:(FBScene *)arg1;
- (void)sceneDidActivate:(FBScene *)arg1;
- (void)sceneDidInvalidate:(FBScene *)arg1;
- (void)sceneDidInvalidate:(FBScene *)arg1 withContext:(FBSSceneTransitionContext *)arg2;
- (void)sceneWillActivate:(FBScene *)arg1;
- (void)sceneWillDeactivate:(FBScene *)arg1 withContext:(FBSSceneTransitionContext *)arg2;
- (void)sceneWillDeactivate:(FBScene *)arg1 withError:(NSError *)arg2;

@end

@protocol FBSceneDelegate <FBSceneObserver>

@optional

- (void)scene:(FBScene *)arg1 didReceiveActions:(NSSet *)arg2;
- (void)scene:(FBScene *)arg1 willUpdateSettings:(FBSSceneUpdate *)arg2;
- (void)scene:(FBScene *)arg1 willUpdateSettings:(FBSMutableSceneSettings *)arg2 withTransitionContext:(FBSSceneTransitionContext *)arg3;
- (void)sceneDidDeactivate:(FBScene *)arg1 withContext:(FBSSceneTransitionContext *)arg2;
- (void)sceneDidDeactivate:(FBScene *)arg1 withError:(NSError *)arg2;

@end

@interface FBScene : NSObject

@property (nonatomic) id<FBSceneDelegate> delegate;
@property (getter=isValid, nonatomic, readonly) bool valid;

- (FBProcess *)clientProcess;
- (UIScenePresentationManager *)uiPresentationManager;
- (void)updateSettings:(UIMutableApplicationSceneSettings *)settings withTransitionContext:(id)context completion:(id)completion;
- (void)updateSettingsWithBlock:(void(^)(UIMutableApplicationSceneSettings *settings))arg1;

@end

@interface FBDisplayManager : NSObject
+ (instancetype)sharedInstance;
- (id)mainConfiguration;
@end

@interface FBSSceneClientIdentity : NSObject
+ (instancetype)identityForBundleID:(NSString *)bundleID;
+ (instancetype)identityForProcessIdentity:(RBSProcessIdentity *)identity;
+ (instancetype)localIdentity;
@end

@interface FBProcessManager : NSObject
+ (instancetype)sharedInstance;
- (FBProcessExecutionContext *)launchProcessWithContext:(FBMutableProcessExecutionContext *)context;
- (id)registerProcessForAuditToken:(audit_token_t)token;
- (id)registerProcessForHandle:(id)arg1;
@end

@interface FBSSceneSpecification : NSObject
+ (instancetype)specification;
@end

// RunningBoardServices
@interface RBSProcessIdentity : NSObject
+ (instancetype)identityForEmbeddedApplicationIdentifier:(NSString *)identifier;
+ (instancetype)identityForXPCServiceIdentifier:(NSString *)identifier;
+ (id)identityForExecutablePath:(id)arg1 pid:(int)arg2 auid:(unsigned int)arg3;
@end

@interface RBSProcessPredicate
+ (id)predicateMatchingIdentity:(id)arg1;
+ (instancetype)predicateMatchingIdentifier:(NSNumber *)pid;
@end

@interface RBSProcessHandle
@property(nonatomic, copy, readonly) RBSProcessIdentity *identity;
+ (instancetype)handleForPredicate:(RBSProcessPredicate *)predicate error:(NSError **)error;
- (audit_token_t)auditToken;
- (bool)isValid;
- (int)pid;
@end

@interface RBSProcessMonitorConfiguration : NSObject <NSCopying>

@property (readonly, copy) NSString *debugDescription; /* unknown property attribute: ? */
@property (readonly, copy) NSString *description;
@property (nonatomic) unsigned long long events;
@property (readonly) unsigned long long hash;
@property (nonatomic, readonly) unsigned long long identifier;
@property (nonatomic, copy) NSArray<RBSProcessPredicate*> *predicates;
@property (nonatomic) unsigned int serviceClass;
@property (readonly) Class superclass;
@property (nonatomic, copy) id /* block */ updateHandler;

+ (bool)supportsRBSXPCSecureCoding;

- (id)copyWithZone:(NSZone)arg1;
- (id)debugDescription;
- (id)description;
- (void)encodeWithRBSXPCCoder:(id)arg1;
- (unsigned long long)events;
- (unsigned long long)hash;
- (unsigned long long)identifier;
- (id)init;
- (id)initWithRBSXPCCoder:(id)arg1;
- (bool)isEqual:(id)arg1;
- (bool)matchesProcess:(id)arg1;
- (id)predicates;
- (unsigned int)serviceClass;
- (void)setEvents:(unsigned long long)arg1;
- (void)setPredicates:(NSArray<RBSProcessPredicate*>*)arg1;
- (void)setPreventLaunchUpdateHandle:(id /* block */)arg1;
- (void)setServiceClass:(unsigned int)arg1;
- (void)setStateDescriptor:(id)arg1;
- (void)setUpdateHandler:(id /* block */)arg1;
- (id)stateDescriptor;
- (id /* block */)updateHandler;

@end

@interface RBSProcessMonitor : NSObject

@property (readonly, copy) NSString *debugDescription; /* unknown property attribute: ? */
@property (readonly, copy) NSString *description;
@property (nonatomic, readonly) unsigned long long events;
@property (readonly) unsigned long long hash;
@property (nonatomic, readonly) unsigned int serviceClass;
@property (nonatomic, readonly, copy) NSSet *states;
@property (readonly) Class superclass;

+ (id)_monitorWithService:(id)arg1;
+ (id)_monitorWithService:(id)arg1 configuration:(id /* block */)arg2;
+ (id)monitor;
+ (id)monitorWithConfiguration:(id /* block */)arg1;
+ (id)monitorWithPredicate:(id)arg1 updateHandler:(id /* block */)arg2;

- (void)_handleExitEvent:(id)arg1;
- (void)_handlePreventLaunchUpdate:(id)arg1;
- (void)_handleProcessStateChange:(id)arg1;
- (id)calloutQueue;
- (id)configuration;
- (id)copyWithZone:(NSZone)arg1;
- (void)dealloc;
- (id)description;
- (unsigned long long)events;
- (id)init;
- (void)invalidate;
- (unsigned int)serviceClass;
- (void)setEvents:(unsigned long long)arg1;
- (void)setPredicates:(id)arg1;
- (void)setPreventLaunchUpdateHandle:(id /* block */)arg1;
- (void)setServiceClass:(unsigned int)arg1;
- (void)setStateDescriptor:(id)arg1;
- (void)setUpdateHandler:(id /* block */)arg1;
- (id)stateForIdentity:(id)arg1;
- (id)states;
- (void)updateConfiguration:(id /* block */)arg1;

@end

@interface RBSProcessState : NSObject <NSCopying>

@property (nonatomic, readonly, copy) NSSet *assertions;
@property (nonatomic, readonly, copy) NSObject<OS_xpc_object> *codedState;
@property (readonly, copy) NSString *debugDescription; /* unknown property attribute: ? */
@property (nonatomic) unsigned char debugState;
@property (getter=isDebugging, nonatomic, readonly) bool debugging;
@property (readonly, copy) NSString *description;
@property (getter=isEmptyState, nonatomic, readonly) bool emptyState;
@property (nonatomic, copy) NSSet *endowmentInfos;
@property (nonatomic, copy) NSSet *endowmentNamespaces;
@property (readonly) unsigned long long hash;
@property (nonatomic, copy) NSSet *legacyAssertions;
@property (getter=isPreventedFromLaunching, nonatomic, readonly) bool preventedFromLaunching;
@property (nonatomic, copy) NSSet *primitiveAssertions;
@property (nonatomic, readonly) RBSProcessHandle *process;
@property (getter=isRunning, nonatomic, readonly) bool running;
@property (readonly) Class superclass;
@property (nonatomic, copy) NSSet *tags;
@property (nonatomic) unsigned char taskState;
@property (nonatomic) unsigned char terminationResistance;

+ (void)setActiveStateDescriptor:(id)arg1;
+ (id)stateWithProcess:(id)arg1;
+ (id)statesForPredicate:(id)arg1 withDescriptor:(id)arg2 error:(out id*)arg3;
+ (id)statesForPredicate:(id)arg1 withDescriptor:(id)arg2 service:(id)arg3 error:(out id*)arg4;
+ (bool)supportsRBSXPCSecureCoding;
+ (id)untrackedRunningStateforProcess:(id)arg1;

- (id)assertions;
- (id)codedState;
- (id)copyWithZone:(NSZone)arg1;
- (unsigned char)debugState;
- (id)description;
- (void)encodeWithPreviousState:(id)arg1;
- (void)encodeWithRBSXPCCoder:(id)arg1;
- (id)endowmentInfos;
- (id)endowmentNamespaces;
- (unsigned long long)hash;
- (id)init;
- (id)initWithRBSXPCCoder:(id)arg1;
- (bool)isDebugging;
- (bool)isDifferentFromState:(id)arg1 significantly:(out bool*)arg2;
- (bool)isEmptyState;
- (bool)isEqual:(id)arg1;
- (bool)isPreventedFromLaunching;
- (bool)isRunning;
- (id)legacyAssertions;
- (id)primitiveAssertions;
- (id)process;
- (void)setDebugState:(unsigned char)arg1;
- (void)setEndowmentInfos:(NSSet*)arg1;
- (void)setEndowmentNamespaces:(NSSet*)arg1;
- (void)setLegacyAssertions:(NSSet*)arg1;
- (void)setPrimitiveAssertions:(NSSet*)arg1;
- (void)setTags:(NSSet*)arg1;
- (void)setTaskState:(unsigned char)arg1;
- (void)setTerminationResistance:(unsigned char)arg1;
- (id)tags;
- (unsigned char)taskState;
- (unsigned char)terminationResistance;

@end

@interface RBSProcessExitStatus : NSObject <NSCopying, NSSecureCoding>

@property (nonatomic, readonly) unsigned long long code;
@property (readonly, copy) NSString *debugDescription; /* unknown property attribute: ? */
@property (readonly, copy) NSString *description;
@property (nonatomic, readonly) unsigned int domain;
@property (readonly) unsigned long long hash;
@property (readonly) Class superclass;

+ (id)statusWithDomain:(unsigned int)arg1 code:(unsigned long long)arg2;
+ (bool)supportsRBSXPCSecureCoding;
+ (bool)supportsSecureCoding;

- (id)_dictionaryRepresentation;
- (id)_initWithDictionaryRepresentation:(id)arg1;
- (bool)_isVoluntary;
- (unsigned long long)code;
- (id)description;
- (unsigned int)domain;
- (void)encodeWithCoder:(id)arg1;
- (void)encodeWithRBSXPCCoder:(id)arg1;
- (id)error;
- (unsigned long long)hash;
- (id)initWithCoder:(id)arg1;
- (id)initWithRBSXPCCoder:(id)arg1;
- (bool)isCrash;
- (bool)isEqual:(id)arg1;
- (bool)isFairPlayFailure;
- (bool)isJetsam;
- (bool)isSignal;
- (bool)isValid;

@end

@interface RBSProcessExitContext : NSObject <NSSecureCoding>

@property (readonly, copy) NSString *debugDescription; /* unknown property attribute: ? */
@property (readonly, copy) NSString *description;
@property (readonly) unsigned long long hash;
@property (nonatomic, readonly) int legacyCode;
@property (nonatomic, readonly) RBSProcessExitStatus *status;
@property (readonly) Class superclass;
@property (nonatomic, readonly) NSDate *timestamp;
@property (nonatomic, readonly) long long type;

+ (id)exitContextForNamespace:(unsigned int)arg1 code:(unsigned long long)arg2 wait4Status:(int)arg3;
+ (bool)supportsRBSXPCSecureCoding;
+ (bool)supportsSecureCoding;

- (id)copyWithStatus:(id)arg1;
- (id)copyWithTerminationContext:(id)arg1;
- (id)copyWithTimestamp:(id)arg1;
- (id)debugDescription;
- (id)description;
- (void)encodeWithCoder:(id)arg1;
- (void)encodeWithRBSXPCCoder:(id)arg1;
- (unsigned long long)hash;
- (id)initWithCoder:(id)arg1;
- (id)initWithRBSXPCCoder:(id)arg1;
- (bool)isEqual:(id)arg1;
- (int)legacyCode;
- (id)status;
- (id)terminationContext;
- (id)timestamp;
- (long long)type;

@end

@interface RBSProcessExitEvent : NSObject {
    RBSProcessExitContext * _context;
    RBSProcessHandle * _process;
}

@property (nonatomic, retain) RBSProcessExitContext *context;
@property (readonly, copy) NSString *debugDescription; /* unknown property attribute: ? */
@property (readonly, copy) NSString *description;
@property (readonly) unsigned long long hash;
@property (nonatomic, retain) RBSProcessHandle *process;
@property (readonly) Class superclass;

+ (bool)supportsRBSXPCSecureCoding;

- (id)context;
- (id)description;
- (void)encodeWithRBSXPCCoder:(id)arg1;
- (unsigned long long)hash;
- (id)initWithRBSXPCCoder:(id)arg1;
- (bool)isEqual:(id)arg1;
- (id)process;
- (void)setContext:(RBSProcessExitContext*)arg1;
- (void)setProcess:(RBSProcessHandle*)arg1;

@end

@interface RBSProcessStateUpdate : NSObject

@property (nonatomic, readonly) RBSProcessExitEvent *exitEvent;
@property (nonatomic, readonly) RBSProcessState *previousState;
@property (nonatomic, readonly) RBSProcessHandle *process;
@property (nonatomic, readonly) RBSProcessState *state;

+ (id)updateWithState:(id)arg1 previousState:(id)arg2 exitEvent:(id)arg3;

- (id)description;
- (id)exitEvent;
- (id)previousState;
- (id)process;
- (id)state;

@end

@interface RBSTarget : NSObject
@end

@interface UIApplicationSceneSpecification : FBSSceneSpecification
@end

@interface FBSSceneIdentity : NSObject
+ (instancetype)identityForIdentifier:(NSString *)id;
@end

// FBSSceneSettings
@interface UIApplicationSceneSettings(Multitask)
- (bool)isForeground;
- (CGRect)frame;
- (UIInterfaceOrientation)interfaceOrientation;
- (UIMutableApplicationSceneSettings *)mutableCopy;
@end

@interface FBScene (a)
- (UIApplicationSceneSettings*)settings;
@end

@interface UIMutableApplicationSceneSettings(Multitask)
@property(nonatomic, assign, readwrite) BOOL canShowAlerts;
@property(nonatomic, assign) BOOL deviceOrientationEventsEnabled;
@property(nonatomic, assign, readwrite) NSInteger interruptionPolicy;
@property(nonatomic, strong, readwrite) NSString *persistenceIdentifier;
@property (nonatomic, assign, readwrite) UIEdgeInsets peripheryInsets;
@property (nonatomic, assign, readwrite) UIEdgeInsets safeAreaInsetsPortrait, safeAreaInsetsPortraitUpsideDown, safeAreaInsetsLandscapeLeft, safeAreaInsetsLandscapeRight;
@property(assign, nonatomic, readwrite) UIUserInterfaceStyle userInterfaceStyle;
@property(assign, nonatomic, readwrite) UIDeviceOrientation deviceOrientation;
@property (nonatomic, strong, readwrite) BSCornerRadiusConfiguration *cornerRadiusConfiguration;
@property (assign,nonatomic) CGRect statusBarAvoidanceFrame;
@property (assign,nonatomic) double statusBarHeight;
@property (assign,nonatomic, getter=isForeground) bool foreground;
- (id)displayConfiguration;
- (CGRect)frame;
- (NSMutableSet *)ignoreOcclusionReasons;
- (void)setDisplayConfiguration:(id)c;
- (void)setForeground:(BOOL)f;
- (void)setFrame:(CGRect)frame;
- (void)setLevel:(NSInteger)level;
- (void)setStatusBarDisabled:(BOOL)disabled;
- (void)setInterfaceOrientation:(NSInteger)o;
- (BSSettings *)otherSettings;
@end

@interface FBSSceneParameters(Multitask)
+ (instancetype)parametersForSpecification:(FBSSceneSpecification *)spec;
//- (void)updateSettingsWithBlock:(id)block;
@end

@interface FBSMutableSceneDefinition : NSObject
@property(nonatomic, copy) FBSSceneClientIdentity *clientIdentity;
@property(nonatomic, copy) FBSSceneIdentity *identity;
@property(nonatomic, copy) FBSSceneSpecification *specification;
+ (instancetype)definition;
@end

@interface FBSceneManager : NSObject
+ (instancetype)sharedInstance;
- (FBScene *)createSceneWithDefinition:(id)def initialParameters:(id)params;
-(void)destroyScene:(id)arg1 withTransitionContext:(id)arg2 ;
@end

@interface FBSSceneSettingsDiff : NSObject
- (UIMutableApplicationSceneSettings *)settingsByApplyingToMutableCopyOfSettings:(UIApplicationSceneSettings *)settings ;
@end

// UIKit
@protocol _UISceneSettingsDiffAction<NSObject>
@required
- (void)_performActionsForUIScene:(UIScene *)scene withUpdatedFBSScene:(id)fbsScene settingsDiff:(FBSSceneSettingsDiff *)diff fromSettings:(id)settings transitionContext:(id)context lifecycleActionType:(uint32_t)actionType;
@end

@interface UIImage(internal)
+ (instancetype)_applicationIconImageForBundleIdentifier:(NSString *)bundleID format:(NSInteger)format scale:(CGFloat)scale;
@end

@interface UIWindow (Private)
- (instancetype)_initWithFrame:(CGRect)frame attached:(BOOL)attached;
- (void)orderFront:(id)arg1;
@end

@interface _UIRootWindow : UIWindow
@end

@interface UIScreen (Private)
- (CGRect)_referenceBounds;
- (id)displayConfiguration;
@end

@interface UIScenePresentationBinder : NSObject
- (void)addScene:(id)scene;
@end

@interface UIScenePresentationManager : NSObject
- (instancetype)_initWithScene:(FBScene *)scene;
- (_UIScenePresenter *)createPresenterWithIdentifier:(NSString *)identifier;
@end

@interface _UIScenePresenterOwner : NSObject
- (instancetype)initWithScenePresentationManager:(UIScenePresentationManager *)manager context:(FBScene *)scene;
@end

@interface _UIScenePresentationView : UIView
//- (instancetype)initWithPresenter:(_UIScenePresenter *)presenter;
@end

@interface _UIScenePresenter : NSObject
@property (nonatomic, assign, readonly) _UIScenePresentationView *presentationView;
@property(nonatomic, assign, readonly) FBScene *scene;
- (instancetype)initWithOwner:(_UIScenePresenterOwner *)manager identifier:(NSString *)scene sortContext:(NSNumber *)context;
- (void)modifyPresentationContext:(void(^)(UIMutableScenePresentationContext *context))block;
- (void)activate;
- (void)deactivate;
- (void)invalidate;
- (bool)isActive;
- (bool)_isHosting;

- (id)newSnapshot;
- (id)newSnapshotPresentationView;

@end

@interface UIRootWindowScenePresentationBinder : UIScenePresentationBinder
- (instancetype)initWithPriority:(int)pro displayConfiguration:(id)c;
@end

@interface UIScenePresentationContext : NSObject
- (UIScenePresentationContext *)_initWithDefaultValues;
@end

@interface _UISceneLayerHostContainerView : UIView
- (instancetype)initWithScene:(FBScene *)scene debugDescription:(NSString *)desc;
- (void)_setPresentationContext:(UIScenePresentationContext *)context;
@end

@interface UIScene(Private)
- (void)_registerSettingsDiffActionArray:(NSArray<id<_UISceneSettingsDiffAction>> *)array forKey:(NSString *)key;
- (void)_unregisterSettingsDiffActionArrayForKey:(NSString *)key;
@end

@interface UIApplication()
- (void)launchApplicationWithIdentifier:(NSString *)identifier suspended:(BOOL)suspended;
@end

@interface UIMutableScenePresentationContext : UIScenePresentationContext
@property(nonatomic, assign) NSUInteger appearanceStyle;
@end

@interface UIViewController(Private)
- (void)viewDidMoveToWindow:(UIWindow *)window shouldAppearOrDisappear:(BOOL)appear;
@end

@interface BKSTouchStream : NSObject {
    unsigned int  _reference;
}

@property unsigned int reference;

- (id)initWithContextID:(unsigned int)arg1 displayUUID:(id)arg2 identifier:(unsigned char)arg3 policy:(id)arg4;
- (void)invalidate;
- (unsigned int)reference;
- (void)setEventDispatchMode:(unsigned char)arg1 ambiguityRecommendation:(unsigned char)arg2 lastTouchTimestamp:(double)arg3;
- (void)setEventDispatchMode:(unsigned char)arg1 lastTouchTimestamp:(double)arg2;
- (void)setReference:(unsigned int)arg1;

@end

/*
 HIT TEST
 */
/* Generated by RuntimeBrowser
   Image: /System/Library/PrivateFrameworks/UIKitCore.framework/UIKitCore
 */

@interface _UISystemGestureWindow : _UIRootWindow

+ (bool)_isSecure;

- (bool)_appearsInLoupe;
- (bool)_extendsScreenSceneLifetime;
- (id)_focusResponder;
- (bool)_isSystemGestureWindow;
- (id)_responderForKeyEvents;
- (bool)_shouldPrepareScreenForWindow;
- (id)_systemGestureView;
- (bool)_usesWindowServerHitTesting;
- (bool)canBecomeKeyWindow;
- (id)hitTest:(CGPoint)arg1 withEvent:(id)arg2;
- (id)initWithDisplay:(id)arg1;
- (id)initWithDisplayConfiguration:(id)arg1;
- (id)initWithScreen:(id)arg1;

@end

@interface BKSTouchStreamPolicy : NSObject {
    bool  _shouldSendAmbiguityRecommendations;
}

@property (nonatomic) bool shouldSendAmbiguityRecommendations;

- (void)setShouldSendAmbiguityRecommendations:(bool)arg1;
- (bool)shouldSendAmbiguityRecommendations;

@end

@interface RBSMachPort : NSObject <NSCopying, NSSecureCoding>

@property (readonly, copy) NSString *debugDescription; /* unknown property attribute: ? */
@property (readonly, copy) NSString *description;
@property (readonly) unsigned long long hash;
@property (readonly) Class superclass;

+ (id)portConsumingRightForPort:(unsigned int)arg1;
+ (id)portForPort:(unsigned int)arg1;
+ (bool)supportsRBSXPCSecureCoding;
+ (bool)supportsSecureCoding;

- (id)copyWithZone:(NSZone)arg1;
- (void)dealloc;
- (void)encodeWithCoder:(id)arg1;
- (void)encodeWithRBSXPCCoder:(id)arg1;
- (unsigned long long)hash;
- (id)initWithCoder:(id)arg1;
- (id)initWithRBSXPCCoder:(id)arg1;
- (void)invalidate;
- (bool)isEqual:(id)arg1;
- (bool)isUsable;
- (unsigned int)port;

@end

@interface UIWindowScene ()

@property (nonatomic, readonly) UIScreenshotService *screenshotService;

@end
