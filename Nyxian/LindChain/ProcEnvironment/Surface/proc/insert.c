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

#include <LindChain/ProcEnvironment/Surface/proc/insert.h>
#include <LindChain/ProcEnvironment/Surface/proc/def.h>
#include <assert.h>

kern_return_t proc_insert(ksurface_proc_t *proc)
{
    assert(proc != NULL);
    
    proc_table_wrlock();
    
    /*
     * checking if maximum amount of processes
     * has been reached already, because first of
     * all launchd has a limitation and second
     * of all we also should.
     */
    if(ksurface->proc_info.proc_count >= PROC_MAX)
    {
        proc_table_unlock();
        return KERN_NO_SPACE;
    }
    
    /*
     * checking for duplicated process presence,
     * because that would be illegal and would
     * cause a reference leak.
     *
     * note: expects a referenced process object
     *       otherwise this proc_getpid() macro
     *       would be unsafe to use here.
     */
    if(radix_lookup(&(ksurface->proc_info.tree), proc_getpid(proc)) != NULL)
    {
        proc_table_unlock();
        return KERN_FAILURE;
    }
    
    /*
     * creating reference for the radix tree so
     * that the kvobject is safe for it's entire
     * lifetime in the radix tree.
     */
    if(!kvo_retain(proc))
    {
        proc_table_unlock();
        return KERN_FAILURE;
    }
    
    /* inserting process into radix tree */
    if(radix_insert(&(ksurface->proc_info.tree), proc_getpid(proc), proc) != 0)
    {
        kvo_release(proc);
        proc_table_unlock();
        return KERN_FAILURE;
    }
    
    /*
     * before heading away, noting new process
     * count down.
     */
    ksurface->proc_info.proc_count++;
    
    proc_table_unlock();
    return KERN_SUCCESS;
}
