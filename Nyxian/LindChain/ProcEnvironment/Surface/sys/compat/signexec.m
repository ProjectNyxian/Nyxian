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

#import <LindChain/ProcEnvironment/Surface/sys/compat/signexec.h>
#import <LindChain/ProcEnvironment/Surface/proc/proc.h>
#import <LindChain/ProcEnvironment/Object/MachOObject.h>
#import <LindChain/Private/mach/fileport.h>

DEFINE_SYSCALL_HANDLER(signexec)
{
    /* checking input mach ports, so attacker cannot do silly things */
    sys_need_in_ports_with_cnt(1);
    
    /* check entitlements */
    if(!entitlement_got_entitlement(proc_getentitlements(sys_proc_copy_), PEEntitlementProcessSpawn))
    {
        sys_return_failure(EPERM);
    }
    
    /* creating file descriptor out of mach fileport */
    int fd = fileport_makefd(in_ports[0]);
    
    /* checking file descriptor */
    if(fd == -1)
    {
        sys_return_failure(EFAULT);
    }
    
    /*
     * create mach object object out of the file descriptor
     * on return the file descriptor is destroyed by default
     * by ARC on the PEObject
     */
    MachOObject *machOObject = [[MachOObject alloc] initWithFileDescriptor:fd withPath:@"I am a silly sillyhead ^^"];
    
    /* null pointer check */
    if(machOObject == NULL)
    {
        close(fd);
        sys_return_failure(EFAULT);
    }
    
    /* signing that shit */
    BOOL success = [machOObject signAndWriteBack];
    
    /* checking if successful */
    if(!success)
    {
        sys_return_failure(EFAULT);
    }
    
    /* now it was successful */
    return 0;
}
