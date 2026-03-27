/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 cr4zyengineer

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

#ifndef PELAUNCHSERVICE_H
#define PELAUNCHSERVICE_H

#import <Foundation/Foundation.h>
#import <LindChain/Multitask/ProcessManager/LDEProcess.h>
#import <os/lock.h>

@interface PELaunchService : NSObject {
    os_unfair_lock _lock;
    LDEProcess *_process;
    NSXPCListenerEndpoint *_endpoint;
    NSDictionary *_dictionary;
    
    /* properties for async access */
    NSString *_executablePath;
    NSString *_serviceIdentifier;
    BOOL _autoRestart;
}

@property (nonatomic,readonly,getter=getProcess) LDEProcess *process;
@property (nonatomic,readonly,getter=getExecutablePath) NSString *executablePath;
@property (nonatomic,readonly,getter=getServiceIdentifier) NSString *serviceIdentifier;
@property (nonatomic,readonly,getter=shouldAutorestart) BOOL autoRestart;

+ (instancetype)launchServiceWithPlistPath:(NSString*)plistPath;
- (instancetype)initWithPlistPath:(NSString*)plistPath;
- (BOOL)isServiceWithServiceIdentifier:(NSString*)serviceIdentifier;

@end

#endif /* PELAUNCHSERVICE_H */
