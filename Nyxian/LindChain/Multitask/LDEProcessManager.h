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

#ifndef LDEPROCESSMANAGER_H
#define LDEPROCESSMANAGER_H

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <LindChain/Private/FoundationPrivate.h>
#import <LindChain/Private/UIKitPrivate.h>
#import <LindChain/ProcEnvironment/posix_spawn.h>
#import <LindChain/ProcEnvironment/Object/FDMapObject.h>
#import <LindChain/ProcEnvironment/Surface/entitlement.h>
#import <LindChain/Multitask/LDEWindowServer.h>

@interface LDEProcessConfiguration : NSObject

@property (nonatomic) pid_t ppid;
@property (nonatomic) uid_t uid;
@property (nonatomic) gid_t gid;
@property (nonatomic) PEEntitlement entitlements;

- (instancetype)initWithParentProcessIdentifier:(pid_t)ppid withUserIdentifier:(uid_t)uid withGroupIdentifier:(gid_t)gid withEntitlements:(PEEntitlement)entitlements;
+ (instancetype)inheriteConfigurationUsingProcessIdentifier:(pid_t)pid;

+ (instancetype)userApplicationConfiguration;
+ (instancetype)systemApplicationConfiguration;
+ (instancetype)configurationForHash:(NSString*)hash;

@end

/*
 Process
 */
@interface LDEProcess : NSObject

@property (nonatomic,strong) NSExtension *extension;
@property (nonatomic,strong) RBSProcessHandle *processHandle;
@property (nonatomic,strong) RBSProcessMonitor *processMonitor;
@property (nonatomic,strong) UIImage *snapshot;

// Process properties
@property (nonatomic,strong) NSUUID *identifier;
@property (nonatomic,strong) NSString *displayName;
@property (nonatomic,strong) NSString *bundleIdentifier;
@property (nonatomic,strong) NSString *executablePath;

// Info properties
@property (nonatomic) pid_t pid;
@property (nonatomic) wid_t wid;

// Background modes suspension fix
@property (nonatomic) BOOL audioBackgroundModeUsage;

// Other boolean flags
@property (nonatomic) BOOL isSuspended;

@property (nonatomic) dispatch_once_t removeOnce;

// Callback
@property (nonatomic, copy) void (^exitingCallback)(void);

- (instancetype)initWithItems:(NSDictionary*)items withConfiguration:(LDEProcessConfiguration*)configuration;
- (instancetype)initWithPath:(NSString*)binaryPath withArguments:(NSArray *)arguments withEnvironmentVariables:(NSDictionary*)environment withMapObject:(FDMapObject*)mapObject withConfiguration:(LDEProcessConfiguration*)configuration;

- (void)sendSignal:(int)signal;
- (BOOL)suspend;
- (BOOL)resume;
- (BOOL)terminate;

- (void)setRequestCancellationBlock:(void(^)(NSUUID *uuid, NSError *error))callback;
- (void)setRequestInterruptionBlock:(void(^)(NSUUID *uuid))callback;
- (void)setExitingCallback:(void(^)(void))callback;

@end

/*
 Process Manager
 */
@interface LDEProcessManager : NSObject

@property (atomic) NSMutableDictionary<NSNumber*,LDEProcess*> *processes;
@property (atomic) dispatch_queue_t syncQueue;

- (instancetype)init;
+ (instancetype)shared;

- (pid_t)spawnProcessWithItems:(NSDictionary*)items withConfiguration:(LDEProcessConfiguration*)configuration;
- (pid_t)spawnProcessWithBundleIdentifier:(NSString *)bundleIdentifier withConfiguration:(LDEProcessConfiguration*)configuration doRestartIfRunning:(BOOL)doRestartIfRunning;
- (pid_t)spawnProcessWithBundleIdentifier:(NSString *)bundleIdentifier withConfiguration:(LDEProcessConfiguration*)configuration;
- (pid_t)spawnProcessWithPath:(NSString*)binaryPath withArguments:(NSArray *)arguments withEnvironmentVariables:(NSDictionary*)environment withMapObject:(FDMapObject*)mapObject withConfiguration:(LDEProcessConfiguration*)configuration process:(LDEProcess**)processReply;

- (void)closeIfRunningUsingBundleIdentifier:(NSString*)bundleIdentifier;
- (LDEProcess*)processForProcessIdentifier:(pid_t)pid;
- (void)unregisterProcessWithProcessIdentifier:(pid_t)pid;
- (BOOL)isExecutingProcessWithBundleIdentifier:(NSString*)bundleIdentifier;

@end

#endif /* LDEPROCESSMANAGER_H */
