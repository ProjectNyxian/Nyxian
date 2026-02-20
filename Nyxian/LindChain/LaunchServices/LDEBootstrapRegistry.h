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

#ifndef LDEBOOTSTRAPREGISTRY_H
#define LDEBOOTSTRAPREGISTRY_H

#import <Foundation/Foundation.h>

@interface LDEBootstrapRegistry : NSObject

@property (nonatomic,strong,readonly) NSMutableDictionary<NSString*,NSXPCListenerEndpoint*> *registry;

- (instancetype)init;
+ (instancetype)shared;

- (NSXPCListenerEndpoint*)getEndpointWithServiceIdentifier:(NSString*)serviceIdentifier;
- (void)setEndpoint:(NSXPCListenerEndpoint*)endpoint forServiceIdentifier:(NSString*)serviceIdentifier;

@end

#endif /* LDEBOOTSTRAPREGISTRY_H */
