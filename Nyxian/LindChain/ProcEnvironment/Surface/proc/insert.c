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

#include <LindChain/ProcEnvironment/Surface/proc/insert.h>
#include <LindChain/ProcEnvironment/Surface/proc/def.h>
#include <assert.h>

ksurface_return_t proc_insert(ksurface_proc_t *proc)
{
    assert(proc != NULL);
    
    /*
     * creating reference for the radix tree so
     * that the kvobject is safe for it's entire
     * lifetime in the radix tree.
     */
    if(!kvo_retain(proc))
    {
        return SURFACE_RETAIN_FAILED;
    }
    
    proc_table_wrlock();
    
    /*
     * checking if maximum amount of processes
     * has been reached already, because first of
     * all launchd has a limitation and second
     * of all we also should.
     *
     * fixme: the limitation is ignored and
     *        ksurface can crash due to the
     *        limitation of launchd, as
     *        the PEProcess API is independent
     *        from the proc API in ksurface.
     */
    if(ksurface->proc_info.proc_count >= PROC_MAX)
    {
        proc_table_unlock();
        kvo_release(proc);
        return SURFACE_LIMIT;
    }
    
    /*
     * checking for duplicated process presence,
     * because that would be illegal and would
     * cause a reference leak.
     */
    if(radix_lookup(&(ksurface->proc_info.tree), proc_getpid(proc)) != NULL)
    {
        proc_table_unlock();
        kvo_release(proc);
        return SURFACE_DUPLICATE;
    }
    
    /* inserting process into radix tree */
    if(radix_insert(&(ksurface->proc_info.tree), proc_getpid(proc), proc) != 0)
    {
        proc_table_unlock();
        kvo_release(proc);
        return SURFACE_FAILED;
    }
    
    /*
     * before heading away, noting new process
     * count down.
     */
    ksurface->proc_info.proc_count++;
    
    proc_table_unlock();
    return SURFACE_SUCCESS;
}
