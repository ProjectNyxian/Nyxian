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

#import <LindChain/ProcEnvironment/Process/PEBootstrapRegistry.h>
#import <os/lock.h>

@implementation PEBootstrapRegistry {
    os_unfair_lock _lock;
}

- (instancetype)init
{
    self = [super init];
    _registry = [[NSMutableDictionary alloc] init];
    _lock = OS_UNFAIR_LOCK_INIT;
    return self;
}

+ (instancetype)shared
{
    static PEBootstrapRegistry *registrySingleton = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        registrySingleton = [[PEBootstrapRegistry alloc] init];
    });
    return registrySingleton;
}

- (NSXPCListenerEndpoint*)getEndpointWithServiceIdentifier:(NSString*)serviceIdentifier
{
    os_unfair_lock_lock(&_lock);
    NSXPCListenerEndpoint *endpoint = _registry[serviceIdentifier];
    os_unfair_lock_unlock(&_lock);
    return endpoint;
}

- (void)setEndpoint:(NSXPCListenerEndpoint*)endpoint forServiceIdentifier:(NSString*)serviceIdentifier
{
    os_unfair_lock_lock(&_lock);
    _registry[serviceIdentifier] = endpoint;
    os_unfair_lock_unlock(&_lock);
}

@end
