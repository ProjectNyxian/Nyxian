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
#import <LindChain/Multitask/ProcessManager/LDEProcess.h>

@interface LDEProcessManager : NSObject

@property (atomic) NSMutableDictionary<NSNumber*,LDEProcess*> *processes;
@property (atomic) dispatch_queue_t syncQueue;

- (instancetype)init;
+ (instancetype)shared;

#if !JAILBREAK_ENV
- (pid_t)spawnProcessWithItems:(NSDictionary*)items withKernelSurfaceProcess:(ksurface_proc_t*)proc;
- (pid_t)spawnProcessWithBundleIdentifier:(NSString *)bundleIdentifier withKernelSurfaceProcess:(ksurface_proc_t*)proc doRestartIfRunning:(BOOL)doRestartIfRunning outPipe:(NSPipe*)outp inPipe:(NSPipe*)inp enableDebugging:(BOOL)enableDebugging;
- (pid_t)spawnProcessWithBundleIdentifier:(NSString *)bundleIdentifier withKernelSurfaceProcess:(ksurface_proc_t*)proc doRestartIfRunning:(BOOL)doRestartIfRunning outPipe:(NSPipe*)outp inPipe:(NSPipe*)inp;
- (pid_t)spawnProcessWithBundleIdentifier:(NSString *)bundleIdentifier withKernelSurfaceProcess:(ksurface_proc_t*)proc doRestartIfRunning:(BOOL)doRestartIfRunning;
- (pid_t)spawnProcessWithPath:(NSString*)binaryPath withArguments:(NSArray *)arguments withEnvironmentVariables:(NSDictionary*)environment withMapObject:(FDMapObject*)mapObject withKernelSurfaceProcess:(ksurface_proc_t*)proc enableDebugging:(BOOL)enableDebugging process:(LDEProcess**)processReply;
#else
- (pid_t)spawnProcessWithBundleID:(NSString*)bundleID;
#endif /* !JAILBREAK_ENV */

- (void)closeIfRunningUsingBundleIdentifier:(NSString*)bundleIdentifier;
- (LDEProcess*)processForProcessIdentifier:(pid_t)pid;
- (void)unregisterProcessWithProcessIdentifier:(pid_t)pid;

@end

#endif /* LDEPROCESSMANAGER_H */
