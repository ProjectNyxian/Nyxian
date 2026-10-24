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

#include <LindChain/ProcEnvironment/Surface/sys/compat/vroot.h>
#include <CoreFoundation/CoreFoundation.h>
#include <os/lock.h>

DEFINE_SYSCALL_HANDLER(vroot)
{
    /* parsing arguments */
    userspace_pointer_t u_path_buf = (userspace_pointer_t)args[0];
    if(u_path_buf == NULL)
    {
        /* size query */
        return (int64_t)(size_t)PATH_MAX;
    }
    
    /* vroot setup */
    static char path[PATH_MAX];
    static size_t size = 0;
    static os_unfair_lock lock = OS_UNFAIR_LOCK_INIT;
    
    /* must be locked */
    os_unfair_lock_lock(&lock);
    if(size == 0)
    {
        /* we gotta get the home path */
        const char *home = getenv("HOME");
        if(home == NULL)
        {
            sys_return_failure_with_errno(EFAULT);
        }
        
        /* and construct the vroot path */
        size = snprintf(path, PATH_MAX, "%s/Documents/rootfs", home) + 1;
    }
    os_unfair_lock_unlock(&lock);
    
    /* copy the string out */
    if(size == 0 || !syscall_copy_out(sys_task_, size, path, u_path_buf))
    {
        sys_return_failure_with_errno(EFAULT);
    }
    
    sys_return;
}
