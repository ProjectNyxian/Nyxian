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

#import <LindChain/Multitask/ProcessManager/LDEProcessConfiguration.h>
#import <LindChain/ProcEnvironment/Server/Trust.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>

@implementation LDEProcessConfiguration

- (instancetype)initWithParentProcessIdentifier:(pid_t)ppid
                             withUserIdentifier:(uid_t)uid
                            withGroupIdentifier:(gid_t)gid
                               withEntitlements:(PEEntitlement)entitlements
{
    self = [super init];
    
    self.ppid = ppid;
    self.uid = uid;
    self.gid = gid;
    self.entitlements = entitlements;
    
    return self;
}

+ (instancetype)inheriteConfigurationUsingProcessIdentifier:(pid_t)pid
{
    ksurface_proc_t proc = {};
    // TODO: Handle error
    ksurface_error_t error = proc_for_pid(pid, &proc);
    return [[self alloc] initWithParentProcessIdentifier:proc_getpid(proc) withUserIdentifier:proc_getruid(proc) withGroupIdentifier:proc_getrgid(proc) withEntitlements:proc_getentitlements(proc)];
}

+ (instancetype)userApplicationConfiguration
{
    return [[self alloc] initWithParentProcessIdentifier:getpid() withUserIdentifier:501 withGroupIdentifier:501 withEntitlements:PEEntitlementUserApplication];
}

+ (instancetype)systemApplicationConfiguration
{
    return [[self alloc] initWithParentProcessIdentifier:getpid() withUserIdentifier:501 withGroupIdentifier:501 withEntitlements:PEEntitlementUserApplication];
}

+ (instancetype)configurationForHash:(NSString*)hash
{
    return [[self alloc] initWithParentProcessIdentifier:getpid() withUserIdentifier:501 withGroupIdentifier:501 withEntitlements:[[TrustCache shared] getEntitlementsForHash:hash]];
}

@end
