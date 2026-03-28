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

#import <LindChain/ProcEnvironment/Surface/sys/compat/signexec.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/Object/MachOObject.h>
#import <LindChain/Private/mach/fileport.h>

DEFINE_SYSCALL_HANDLER(signexec)
{    
    /* syscall wrapper */
    sys_need_in_ports(1, MACH_MSG_TYPE_MOVE_SEND);
    
    /*
     * checking entitlements weither the process is entitled enough to
     * sign unsigned binaries for opening or executing them, this is
     * done by checking if it is entitled to spawn processes, this
     * entitlement is meant to be a arbitary spawn entitlement against
     * equevalents like PEEntitlementProcessSpawnSignedOnly which is
     * used to only allow the spawn of binaries which are already signed.
     * all this is done to ensure the user does consent do these things!
     */
    if(!entitlement_got_entitlement(proc_getentitlements(sys_proc_), PEEntitlementProcessSpawn))
    {
        sys_return_failure(EPERM);
    }
    
    /*
     * create mach object object out of the file descriptor
     * on return the file descriptor is destroyed by default
     * by ARC on the PEObject
     */
    MachOObject *machOObject = [MachOObject objectForFilePort:sys_in_ports[0]];
    if(machOObject == NULL)
    {
        sys_return_failure(EBADF);
    }
    
    /* signing that shit */
    if(![machOObject signAndWriteBack])
    {
        sys_return_failure(ENOEXEC);
    }
    
    /* now it was successful */
    sys_return;
}
