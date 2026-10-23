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

#include <LindChain/ProcEnvironment/Surface/proc/remove.h>

kern_return_t proc_remove_by_pid__nolock(pid_t pid)
{
    /*
     * removing process from radix tree, which is also
     * where its first reference lives at.
     */
    ksurface_proc_t *proc = radix_remove(&(ksurface->proc_info.tree), pid);
    
    /*
     * radix_remove always returns the process
     * structure, that previously was inserted at that
     * pid slot. if its NULL it means there was never a
     * pid so this is also a was process in tree check.
     */
    if(proc == NULL)
    {
        return KERN_NOT_FOUND;
    }
    
    /*
     * decrementing count of processes so its
     * correctly counted.
     */
    ksurface->proc_info.proc_count--;
    
    /*
     * invalidating object and removing its
     * origin reference that lived in the
     * radix tree.
     */
    kvo_invalidate(proc);
    kvo_release(proc);

    return KERN_SUCCESS;
}

kern_return_t proc_remove_by_pid(pid_t pid)
{
    proc_table_wrlock();
    kern_return_t kr = proc_remove_by_pid__nolock(pid);
    proc_table_unlock();
    return kr;
}
