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

#ifndef LDEPROCESS_H
#define LDEPROCESS_H

#import <Foundation/Foundation.h>
#import <LindChain/Private/FoundationPrivate.h>
#import <LindChain/Private/UIKitPrivate.h>
#import <LindChain/Multitask/WindowServer/LDEWindowServer.h>
#import <LindChain/ProcEnvironment/Object/FDMapObject.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>

@class LDEWindowSessionApplication;

@interface LDEProcess : NSObject <FBSceneDelegate>

#if !JAILBREAK_ENV
@property (nonatomic,strong) NSExtension *extension;
@property (nonatomic) ksurface_proc_t *proc;
#endif /* !JAILBREAK_ENV */

@property (nonatomic,weak) LDEWindowSessionApplication *session;
@property (nonatomic,strong) RBSProcessHandle *processHandle;
@property (nonatomic,strong) RBSProcessMonitor *processMonitor;
@property (nonatomic,strong) FBScene *scene;
@property (nonatomic,strong) NSString *sceneID;
@property (nonatomic) dispatch_once_t notifyWindowManagerOnce;
@property (nonatomic,strong) UIImage *snapshot;

// Process properties
@property (nonatomic,strong) NSUUID *identifier;
@property (nonatomic,strong) NSString *bundleIdentifier;

@property (nonatomic,strong) NSString *displayName;
@property (nonatomic,strong) NSString *executablePath;

// Info properties
@property (nonatomic) pid_t pid;
@property (nonatomic) wid_t wid;

// Background modes suspension fix
@property (nonatomic) BOOL audioBackgroundModeUsage;

// Other boolean flags
@property (nonatomic) BOOL isSuspended;

@property (nonatomic) dispatch_once_t removeOnce;
@property (nonatomic) dispatch_once_t addOnce;

// Callback
@property (nonatomic, copy) void (^exitingCallback)(void);

#if !JAILBREAK_ENV
- (instancetype)initWithItems:(NSDictionary*)items withKernelSurfaceProcess:(ksurface_proc_t*)proc withSession:(LDEWindowSessionApplication*)session;
#else
- (instancetype)initWithBundleID:(NSString*)bundleID;
#endif /* !JAILBREAK_ENV */

- (void)sendSignal:(int)signal;
- (BOOL)suspend;
- (BOOL)resume;
- (BOOL)terminate;

- (void)setExitingCallback:(void(^)(void))callback;

@end

#endif /* LDEPROCESS_H */
