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

#ifndef SERVICEKIT_SERVICE_H
#define SERVICEKIT_SERVICE_H

#import <Foundation/Foundation.h>
#import <ServiceKit/ServiceProtocol.h>

@interface ServiceServer : NSObject <NSXPCListenerDelegate>

@property (nonatomic,strong) Protocol *serverProtocol;
@property (nonatomic,strong) Protocol *observerProtocol;
@property (nonatomic,strong) Class instanceClass;
@property (nonatomic,strong) id instance;
@property (nonatomic,strong) NSXPCListener *listener;
@property (nonatomic) dispatch_once_t anonymousCraftOnce;
@property (nonatomic) NSMutableArray<NSXPCConnection*> *clients;

- (instancetype)initWithClass:(Class)instanceClass withServerProtocol:(Protocol *)serverProtocol withObserverProtocol:(Protocol *)observerProtocol;
+ (instancetype)sharedService;

- (NSXPCListenerEndpoint*)getEndpointForConnection;

@end

int LDEServiceMain(int argc, char *argv[], Class<LDEServiceProtocol> serviceClass, Protocol *clientProtocol);

#endif /* SERVICEKIT_SERVICE_H */
