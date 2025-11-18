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

#ifndef PROCENVIRONMENT_SERVER_SERVERSESSION_H
#define PROCENVIRONMENT_SERVER_SERVERSESSION_H

#import <Foundation/Foundation.h>
#import <LindChain/Private/UIKitPrivate.h>
#import <LindChain/ProcEnvironment/Server/ServerProtocol.h>

@interface ServerSession: NSObject <ServerProtocol>

@property (nonatomic) pid_t processIdentifier;
@property (nonatomic) dispatch_once_t handoffProcessIdentifierOnce;
@property (nonatomic) dispatch_once_t handoffSurfaceOnce;
@property (nonatomic) dispatch_once_t makeWindowVisibleOnce;
@property (nonatomic) dispatch_once_t sendPortOnce;
@property (nonatomic) dispatch_once_t waitTrapOnce;

@end

#endif /* PROCENVIRONMENT_SERVER_SERVERSESSION_H */
