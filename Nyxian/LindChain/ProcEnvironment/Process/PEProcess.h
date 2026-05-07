/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 mach-port-t

 This file is part of Nyxian.

 Nyxian is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 Nyxian is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with Nyxian. If not, see <https://www.gnu.org/licenses/>.
*/

#ifndef PRPROCESS_H
#define PRPROCESS_H

#import <Foundation/Foundation.h>
#import <LindChain/Private/FoundationPrivate.h>
#import <LindChain/Private/UIKitPrivate.h>
#import <LindChain/WindowServer/NXWindowServer.h>
#import <LindChain/ProcEnvironment/Object/FDMapObject.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>

@class NXWindowSessionApplication;

@interface PEProcess : NSObject <FBProcessObserver,FBProcessManagerObserver,FBSceneDelegate>

#if !JAILBREAK_ENV
@property (nonatomic) ksurface_proc_t *proc;
#endif /* !JAILBREAK_ENV */

@property (nonatomic,weak) NXWindowSessionApplication *session;
@property (nonatomic,strong) FBProcess *process;
@property (nonatomic,strong) FBScene *scene;
@property (nonatomic,strong) UIImage *snapshot;

// Process properties
@property (nonatomic,strong) NSString *bundleIdentifier;
@property (nonatomic,strong) NSString *displayName;
@property (nonatomic,strong) NSString *executablePath;

// Info properties
@property (nonatomic) pid_t pid;
@property (nonatomic) id_t wid;

// Background modes suspension fix
@property (nonatomic) BOOL audioBackgroundModeUsage;

// Other boolean flags
@property (nonatomic) BOOL isSuspended;

// Callback
@property (nonatomic, copy) void (^exitingCallback)(void);

#if !JAILBREAK_ENV
- (instancetype)initWithItems:(NSDictionary*)items withKernelSurfaceProcess:(ksurface_proc_t*)proc withSession:(NXWindowSessionApplication*)session;
#endif /* !JAILBREAK_ENV */

- (void)sendSignal:(int)signal;
- (BOOL)suspend;
- (BOOL)resume;
- (BOOL)terminate;

- (void)setExitingCallback:(void(^)(void))callback;

@end

#endif /* PRPROCESS_H */
