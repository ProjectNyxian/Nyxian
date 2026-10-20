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

#import <LindChain/ProcEnvironment/Surface/sys/compat/sign.h>
#import <LindChain/ProcEnvironment/LiveContainer/LCUtils.h>
#import <LindChain/ProcEnvironment/Utils/vnode.h>
#import <LindChain/Private/mach/fileport.h>

DEFINE_SYSCALL_HANDLER(sign)
{
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
    if(!entitlement_got_entitlement(proc_getentitlements(sys_proc_), kPEEntitlementFlagProcessSpawn))
    {
        sys_return_failure_with_errno(EPERM);
    }
    
    /* extract file descriptor out of mach port capability */
    fileport_t fp = sys_in_ports[0];
    int fd = fileport_makefd(fp);
    if(fd < 0)
    {
        sys_return_failure_with_errno(EBADF);
    }
    
    int flags = fcntl(fd, F_GETFL);
    if(flags == -1)
    {
        close(fd);
        sys_return_failure_with_errno(EBADF);
    }
    
    if((flags & O_ACCMODE) != O_RDWR)
    {
        close(fd);
        sys_return_failure_with_errno(EBADF);
    }
    
    char path[MAXPATHLEN];
    if(fcntl(fd, F_GETPATH, path) != 0)
    {
        close(fd);
        sys_return_failure_with_errno(EBADF);
    }
    
    uint8_t cdhash[USER_FSIGNATURES_CDHASH_LEN];
    bool success = CDHashOfFD(fd, (uint8_t*)&cdhash);
    close(fd);
    if(!success)
    {
        sys_return_failure_with_errno(ENOEXEC);
    }
    
    int vfd = vnode_inaccessible_open(path, O_RDWR);
    if(CDHashMatchesCodeDirectoryFD(vfd, (const unsigned char*)cdhash) != KERN_SUCCESS)
    {
        vnode_inaccessible_close(vfd, false);
        sys_return_failure_with_errno(EIO); /* file got swapped */
    }
    
    if(fcntl(vfd, F_GETPATH, path) != 0)
    {
        vnode_inaccessible_close(vfd, false);
        sys_return_failure_with_errno(EBADF);
    }
    
    NSString *nsPath = [NSString stringWithCString:path encoding:NSUTF8StringEncoding];
    if(nsPath == nil)
    {
        vnode_inaccessible_close(vfd, false);
        sys_return_failure_with_errno(ENOMEM);
    }
    
    /* signing that shit */
    if(![LCUtils signMachOAtURL:[NSURL fileURLWithPath:nsPath]])
    {
        vnode_inaccessible_close(vfd, false);
        sys_return_failure_with_errno(ENOEXEC);
    }
    vnode_inaccessible_close(vfd, true);
    
    sys_return;
}
