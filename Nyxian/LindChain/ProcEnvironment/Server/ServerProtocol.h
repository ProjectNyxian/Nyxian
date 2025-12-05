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

#ifndef PROCENVIRONMENT_SERVER_SERVERPROTOCOL_H
#define PROCENVIRONMENT_SERVER_SERVERPROTOCOL_H

#import <Foundation/Foundation.h>
#import <LindChain/Private/UIKitPrivate.h>
#import <LindChain/Multitask/ProcessManager/LDEProcessManager.h>
#import <LindChain/ProcEnvironment/Object/MachPortObject.h>
#import <LindChain/ProcEnvironment/Object/TaskPortObject.h>
#import <LindChain/ProcEnvironment/Object/MachOObject.h>
#import <LindChain/ProcEnvironment/posix_spawn.h>
#import <LindChain/ProcEnvironment/Surface/surface.h>

@protocol ServerProtocol

/*
 tfp_userspace
 */
- (void)sendPort:(TaskPortObject*)machPort;
- (void)getPort:(pid_t)pid withReply:(void (^)(TaskPortObject*))reply;

/*
 posix_spawn
 */
- (void)spawnProcessWithPath:(NSString*)path withArguments:(NSArray*)arguments withEnvironmentVariables:(NSDictionary *)environment withMapObject:(FDMapObject*)mapObject withReply:(void (^)(unsigned int))reply;

/*
 Process Info
 */
- (void)getProcessNyxWithIdentifier:(pid_t)pid withReply:(void (^)(NSData*))reply;

/*
 Signer
 */
- (void)signMachO:(MachOObject*)object withReply:(void (^)(void))reply;

/*
 Launch Services
 */
- (void)setEndpoint:(NSXPCListenerEndpoint*)endpoint forServiceIdentifier:(NSString*)serviceIdentifier;
- (void)getEndpointOfServiceIdentifier:(NSString*)serviceIdentifier withReply:(void (^)(NSXPCListenerEndpoint *result))reply;

/*
 App Switcher Servuces
 */
- (void)setSnapshot:(UIImage*)image;

- (void)waitTillAddedTrapWithReply:(void (^)(BOOL added))reply;

@end

#endif /* PROCENVIRONMENT_SERVER_SERVERPROTOCOL_H */
