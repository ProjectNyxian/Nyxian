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

#ifndef LDEPROCESSCONFIGURATION_H
#define LDEPROCESSCONFIGURATION_H

#import <Foundation/Foundation.h>
#import <LindChain/ProcEnvironment/Surface/entitlement.h>

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

#endif /* LDEPROCESSCONFIGURATION_H */
