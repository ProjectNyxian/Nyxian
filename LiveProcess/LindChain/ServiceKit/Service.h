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
#import <LindChain/ServiceKit/ServiceProtocol.h>

@interface ServiceServer : NSObject <NSXPCListenerDelegate>

@property (nonatomic,strong) Protocol *protocol;
@property (nonatomic,strong) Class instanceClass;
@property (nonatomic,strong) NSXPCListener *listener;
@property (nonatomic) dispatch_once_t anonymousCraftOnce;

- (instancetype)initWithClass:(Class)instanceClass withProtocol:(Protocol*)instanceProtocol;
+ (instancetype)serverWithClass:(Class)instanceClass withProtocol:(Protocol*)instanceProtocol;
+ (instancetype)sharedService;

- (NSXPCListenerEndpoint*)getEndpointForConnection;

@end

int LDEServiceMain(int argc, char *argv[], Class<LDEServiceProtocol> serviceClass);

#endif /* SERVICEKIT_SERVICE_H */
