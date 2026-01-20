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

#ifndef PROC_ENTITLEMENT_H
#define PROC_ENTITLEMENT_H

#import <Foundation/Foundation.h>
#include <stdint.h>

/*!
 @enum PEEntitlement
 @abstract Entitlements which are responsible for the permitives of the environment hostsided
 */
typedef NS_OPTIONS(uint64_t, PEEntitlement) {
    /*! Grants other processes with appropriate permitives to get task port of process .*/
    PEEntitlementGetTaskAllowed                     = 1ull << 0,
    
    /*! Grants process to get task port of processes. */
    PEEntitlementTaskForPid                         = 1ull << 1,
    
    /*! Grants process to get task port of Nyxian it self. */
    PEEntitlementTaskForPidHost                     = 1ull << 2,
    
    /*! Grants process to enumerate processes. */
    PEEntitlementProcessEnumeration                 = 1ull << 3,
    
    /*! Grants process to kill other processes. */
    PEEntitlementProcessKill                        = 1ull << 5,
    
    /*! Grants process to spawn other processes. */
    PEEntitlementProcessSpawn                       = 1ull << 6,
    
    /*! Grants process to spawn other processes, under the condition that the binary must be signed. */
    PEEntitlementProcessSpawnSignedOnly             = 1ull << 7,
    
    /*! Grants process to elevate permitive. */
    PEEntitlementProcessElevate                     = 1ull << 8,
    
    /*! Grants process to manage host. */
    PEEntitlementHostManager                        = 1ull << 9,
    
    /*! Grants process to manage credentials. */
    PEEntitlementCredentialsManager                 = 1ull << 10,
    
    /*! Grants process to start launch services. */
    PEEntitlementLaunchServicesStart                = 1ull << 11,
    
    /*! Grants process to stop launch services. */
    PEEntitlementLaunchServicesStop                 = 1ull << 12,
    
    /*! Grants process to manage launch services. */
    PEEntitlementLaunchServicesToggle               = 1ull << 13,
    
    /*! Grants process to get endpoint of launch services. */
    PEEntitlementLaunchServicesGetEndpoint          = 1ull << 14,
    
    /*! Grants process to manage launch services. */
    PEEntitlementLaunchServicesManager              = PEEntitlementLaunchServicesStart | PEEntitlementLaunchServicesStop | PEEntitlementLaunchServicesToggle | PEEntitlementLaunchServicesGetEndpoint,
    
    /*! Grants process to read from trust cache. */
    PEEntitlementTrustCacheRead                     = 1ull << 15,
    
    /*! Grants process to write to trust cache. (caution: never use this) */
    PEEntitlementTrustCacheWrite                    = 1ull << 16,
    
    /*! Grants process to manage trust cache */
    PEEntitlementTrustCacheManager                  = PEEntitlementTrustCacheRead | PEEntitlementTrustCacheWrite,
    
    /*! Enforces device spoofing settings */
    PEEntitlementEnforceDeviceSpoof                 = 1ull << 17,
    
    /*! Hides LiveProcess in DYLD Api. (recommended) */
    PEEntitlementDyldHideLiveProcess                = 1ull << 18,
    
    /*! Makes a process retain entitlements across processes, made for sandboxed applications and such. Its a security feature. */
    PEEntitlementProcessSpawnInheriteEntitlements   = 1ull << 19,
    
    /*! Security feature for daemons and such */
    PEEntitlementPlatform                           = 1ull << 20,
    
    PEEntitlementSandboxedApplication               = PEEntitlementGetTaskAllowed | PEEntitlementProcessSpawnInheriteEntitlements,
    PEEntitlementUserApplication                    = PEEntitlementGetTaskAllowed | PEEntitlementProcessSpawnInheriteEntitlements | PEEntitlementProcessEnumeration | PEEntitlementProcessKill | PEEntitlementProcessSpawnSignedOnly | PEEntitlementLaunchServicesGetEndpoint | PEEntitlementDyldHideLiveProcess,
    PEEntitlementSystemApplication                  = PEEntitlementTaskForPid | PEEntitlementProcessEnumeration | PEEntitlementProcessKill | PEEntitlementProcessSpawn | PEEntitlementProcessElevate | PEEntitlementLaunchServicesManager | PEEntitlementTrustCacheRead | PEEntitlementDyldHideLiveProcess,
    PEEntitlementSystemDaemon                       = PEEntitlementTaskForPid | PEEntitlementProcessEnumeration | PEEntitlementProcessKill | PEEntitlementProcessSpawn | PEEntitlementProcessElevate | PEEntitlementLaunchServicesManager | PEEntitlementTrustCacheRead | PEEntitlementDyldHideLiveProcess | PEEntitlementPlatform,
    PEEntitlementKernel                             = PEEntitlementGetTaskAllowed | PEEntitlementTaskForPid | PEEntitlementTaskForPidHost | PEEntitlementProcessEnumeration | PEEntitlementProcessKill | PEEntitlementProcessSpawn | PEEntitlementProcessSpawnSignedOnly | PEEntitlementProcessElevate | PEEntitlementHostManager | PEEntitlementCredentialsManager | PEEntitlementLaunchServicesManager | PEEntitlementTrustCacheManager | PEEntitlementPlatform
};

bool entitlement_got_entitlement(PEEntitlement present, PEEntitlement needed);

#endif /* PROC_ENTITLEMENT_H */
