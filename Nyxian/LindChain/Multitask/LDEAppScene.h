//
//  AppSceneView.h
//  LiveContainer
//
//  Created by s s on 2025/5/17.
//

/*#ifndef APPSCENE_H
#define APPSCENE_H

#import <LindChain/Private/UIKitPrivate.h>
#import <Project/NXProject.h>
#import "FoundationPrivate.h"
#import <LindChain/Services/applicationmgmtd/LDEApplicationWorkspace.h>
#import <UIKit/UIKit.h>
#import <Foundation/Foundation.h>
#import <LindChain/Multitask/LDEProcessManager.h>

@class LDEAppScene;

@protocol LDEAppSceneDelegate <NSObject>

- (void)appSceneVCAppDidExit:(LDEAppScene*)vc;
- (void)appSceneVC:(LDEAppScene*)vc didInitializeWithError:(NSError*)error;

@optional

- (void)appSceneVC:(LDEAppScene*)vc didUpdateFromSettings:(UIMutableApplicationSceneSettings *)settings transitionContext:(id)context;

@end

@interface LDEAppScene : UIViewController<_UISceneSettingsDiffAction>

@property (nonatomic) LDEProcess *process;
@property (nonatomic) NSString *sceneID;
@property(nonatomic) void(^nextUpdateSettingsBlock)(UIMutableApplicationSceneSettings *settings);
@property(nonatomic, weak) id<LDEAppSceneDelegate> delegate;
@property(nonatomic) CGFloat scaleRatio;
@property(nonatomic) UIView* contentView;
@property(nonatomic) _UIScenePresenter *presenter;
@property (nonatomic, copy) void (^pendingSettingsBlock)(UIMutableApplicationSceneSettings *settings);
@property(nonatomic) UIMutableApplicationSceneSettings *settings;

- (instancetype)initWithProcess:(LDEProcess*)process
                   withDelegate:(id<LDEAppSceneDelegate>)delegate;
- (void)setBackgroundNotificationEnabled:(bool)enabled;
- (void)resizeActionStart;
- (void)resizeActionEnd;
- (void)setForegroundEnabled:(BOOL)foreground;

@end*/

//#endif /* APPSCENE_H */
