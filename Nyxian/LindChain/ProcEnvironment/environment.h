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

#ifndef PROCENVIRONMENT_ENVIRONMENT_H
#define PROCENVIRONMENT_ENVIRONMENT_H

/* ----------------------------------------------------------------------
 *  Apple API Headers
 * -------------------------------------------------------------------- */
#import <Foundation/Foundation.h>

/* ----------------------------------------------------------------------
 *  Environment API Headers
 * -------------------------------------------------------------------- */
#import <LindChain/ProcEnvironment/proxy.h>
#import <LindChain/ProcEnvironment/tfp.h>
#import <LindChain/ProcEnvironment/libproc.h>
#import <LindChain/ProcEnvironment/application.h>
#import <LindChain/ProcEnvironment/posix_spawn.h>
#import <LindChain/ProcEnvironment/sysctl.h>
#import <LindChain/ProcEnvironment/ioctl.h>
#import <LindChain/ProcEnvironment/vfork.h>
#import <LindChain/ProcEnvironment/cred.h>
#import <LindChain/ProcEnvironment/Object/MachPortObject.h>
#import <LindChain/ProcEnvironment/Object/FDMapObject.h>
#import <LindChain/ProcEnvironment/Surface/surface.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/Surface/permit.h>
#import <LindChain/ProcEnvironment/Surface/entitlement.h>

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

 @param mpo
    Mach port send by the host environment to the guest to connect to.
 */
void environment_client_connect_to_syscall_proxy(MachPortObject *mpo);

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

#endif /* PROCENVIRONMENT_ENVIRONMENT_H */
