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

#ifndef PROC_ENTITLEMENT_H
#define PROC_ENTITLEMENT_H

#include <LindChain/ProcEnvironment/Surface/return.h>
#ifdef __OBJC__
#import <Foundation/Foundation.h>
#endif /* __OBJC__ */
#include <stdint.h>
#include <stdlib.h>
#include <stdbool.h>
#include <fcntl.h>

typedef struct ksurface_proc ksurface_proc_t;
typedef struct ksurface_ent_blob ksurface_ent_blob_t;
typedef struct ksurface_ent_result ksurface_ent_result_t;

/*!
 @enum PEEntitlement
 @abstract Entitlements which are responsible for the permitives of the environment hostsided
 */
#ifdef __OBJC__
typedef NS_OPTIONS(uint64_t, PEEntitlement) {
#else
typedef enum {
#endif /* __OBJC__ */
    /*! No entitlements at all */
    PEEntitlementNone                               = 0,
    
    /*! Grants other processes with appropriate permitives to get task port of process .*/
    PEEntitlementGetTaskAllowed                     = 1ull << 0,
    
    /*! Grants process to get task port of processes. */
    PEEntitlementTaskForPid                         = 1ull << 1,
    
    /*
     * MARK: banned, because too powerful and replaced with PEEntitlementPlatform
     *
     * PEEntitlementTaskForPidHost                     = 1ull << 2,
     */
    
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
    
    /*! Grants process to set endpoint of launch services. */
    PEEntitlementLaunchServicesSetEndpoint          = 1ull << 15,
    
    /*! Grants process to manage launch services. */
    PEEntitlementLaunchServicesManager              = PEEntitlementLaunchServicesStart | PEEntitlementLaunchServicesStop | PEEntitlementLaunchServicesToggle | PEEntitlementLaunchServicesSetEndpoint | PEEntitlementLaunchServicesGetEndpoint,
    
    /*
     * MARK: there is no device spoofing currently, but preserving for the future 
     *
     * PEEntitlementEnforceDeviceSpoof                 = 1ull << 17,
     */
    
    /*! Hides LiveProcess in DYLD Api. (recommended) */
    PEEntitlementDyldHideLiveProcess                = 1ull << 18,   /* TODO: this is the opposite of a capability, better rename to PEEntitlementDyldDontHideEnvironment */
    
    /*! Makes a process retain entitlements across processes, made for sandboxed applications and such. Its a security feature. */
    PEEntitlementProcessSpawnInheriteEntitlements   = 1ull << 19,
    
    /*! Security feature for daemons and such */
    PEEntitlementPlatform                           = 1ull << 20,
    
    PEEntitlementSandboxedApplication               = PEEntitlementNone,
    PEEntitlementUserApplication                    = PEEntitlementGetTaskAllowed | PEEntitlementProcessSpawnInheriteEntitlements | PEEntitlementProcessEnumeration | PEEntitlementProcessKill | PEEntitlementProcessSpawnSignedOnly | PEEntitlementLaunchServicesGetEndpoint | PEEntitlementDyldHideLiveProcess,
    PEEntitlementSystemApplication                  = PEEntitlementTaskForPid | PEEntitlementProcessEnumeration | PEEntitlementProcessKill | PEEntitlementProcessSpawn | PEEntitlementProcessElevate | PEEntitlementLaunchServicesManager | PEEntitlementDyldHideLiveProcess,
    PEEntitlementSystemDaemon                       = PEEntitlementTaskForPid | PEEntitlementProcessEnumeration | PEEntitlementProcessKill | PEEntitlementProcessSpawn | PEEntitlementProcessElevate | PEEntitlementLaunchServicesManager | PEEntitlementDyldHideLiveProcess | PEEntitlementPlatform,
    PEEntitlementKernel                             = PEEntitlementGetTaskAllowed | PEEntitlementTaskForPid | PEEntitlementProcessEnumeration | PEEntitlementProcessKill | PEEntitlementProcessSpawn | PEEntitlementProcessSpawnSignedOnly | PEEntitlementProcessElevate | PEEntitlementHostManager | PEEntitlementCredentialsManager | PEEntitlementLaunchServicesManager | PEEntitlementPlatform
#ifdef __OBJC__
};
#else
} PEEntitlement;
#endif /* __OBJC__ */
    
struct __attribute__((packed)) ksurface_ent_blob {
    PEEntitlement entitlement;
    char cdhash[USER_FSIGNATURES_CDHASH_LEN];
    uint64_t nonce;
    uint8_t mac[72];
    size_t mac_len;
};

struct __attribute__((packed)) ksurface_ent_result {
    struct ksurface_ent_blob blob;
    char cdhash[USER_FSIGNATURES_CDHASH_LEN];
    bool cdhash_valid;
    bool blob_valid;
};

#define entitlement_got_entitlement(present,needed) ((present & needed) == needed)

ksurface_return_t entitlement_token_mach_gen(ksurface_ent_blob_t *blob, const char *cdhash, PEEntitlement entitlement);
ksurface_return_t entitlement_mach_verify(ksurface_ent_result_t *mach, uint8_t *pub_key, size_t pub_key_len);

#endif /* PROC_ENTITLEMENT_H */
