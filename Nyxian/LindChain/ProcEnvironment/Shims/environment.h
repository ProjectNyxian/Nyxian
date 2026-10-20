/*
 SPDX-License-Identifier: LicenseRef-EPSL-1.1

 Copyright (C) 2025 - 2026 emexlab

 This file is part of Nyxian.

 Licensed under the emexLabs Public Source License, version 1.1
 (EPSL 1.1).

 Private use and modification are permitted under the license.
 Redistribution of source or binaries, modified or unmodified,
 requires prior written permission from emexLabs.

 External deployment is subject to the source-availability
 requirements and other conditions of the license.

 Provided "AS IS", without warranty, to the extent permitted by law.

 See LICENSE for the full license terms.
*/

#ifndef PROCENVIRONMENT_ENVIRONMENT_H
#define PROCENVIRONMENT_ENVIRONMENT_H

/* ----------------------------------------------------------------------
 *  Apple API Headers
 * -------------------------------------------------------------------- */
#import <Foundation/Foundation.h>

/* ----------------------------------------------------------------------
 *  Environment API Headers
 * -------------------------------------------------------------------- */
#import <LindChain/ProcEnvironment/PEMachPort.h>
#import <LindChain/ProcEnvironment/PEFileTable.h>
#import <LindChain/ProcEnvironment/Shims/proxy.h>
#import <LindChain/ProcEnvironment/Shims/application.h>
#import <LindChain/ProcEnvironment/Shims/posix_spawn.h>
#import <LindChain/ProcEnvironment/Shims/vfork.h>
#import <LindChain/ProcEnvironment/Surface/surface.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/Surface/trust/entitlement.h>

/*!
 @enum `EnvironmentExec`
 @abstract Defines how the environment shall be executed.
 */
typedef NS_ENUM(NSInteger, EnvironmentExec) {
    /*! No environment execution type set */
    EnvironmentExecNone = 0,
    
    /*! The environment will execute after init using LiveContainer and will return the exit code of the executable from `environment_init` */
    EnvironmentExecLiveContainer = 1,
    
    /*! The environment wont execute anything and will straightup return for a custom execution method `environment_init` */
    EnvironmentExecCustom  = 2,
};

/*!
 @function `environment_client_connect_to_host`
 @abstract Connects the client to the host environment using a preshipped endpoint.
 @discussion
    This function establishes a connection between a guest process and
    its host environment. The provided endpoint must have been exported
    by the host.

 @param endpoint
    Endpoint send by the host environment to the guest to connect to.
 */
void environment_client_connect_to_host(NSXPCListenerEndpoint *endpoint) __attribute__((deprecated("Use environment_client_connect_to_syscall_proxy(1) instead")));

/*!
 @function `environment_client_connect_to_syscall_proxy`
 @abstract Connects the client to the syscall proxy using a preshipped mach port object(mpo).
 @discussion
    This function establishes a connection between a guest process and
    its host environments syscall proxy. The provided endpoint must have been exported
    by the host.

 @param port
    Mach port send by the host environment to the guest to connect to.
 */
void environment_client_connect_to_syscall_proxy(PEMachPort *port);

/*!
 @function `environment_init`
 @abstract Initializes the environment with a given role.
 @discussion
    This function initializes the environment with the given role. It can and shall only be called once.
 
 @param exec
    Represents how the environment shall act after init.
 @param executablePath
    Executable path of the target binary.
 @param argc
    Item count of argv array.
 @param argv
    Arguments used for the binary.
 @return
    Exit code of the process or environment it self.
 */
int environment_init(EnvironmentExec exec, NSString *executablePath, int argc, char *argv[]);

/*!
 @function `environment_signal_routing_init`
 @abstract Makes the main thread the only receiver of process directed signals until the guest runs. Call as early as possible.
 */
void environment_signal_routing_init(void);

#endif /* PROCENVIRONMENT_ENVIRONMENT_H */
