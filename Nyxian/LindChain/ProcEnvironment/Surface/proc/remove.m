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

#import <LindChain/ProcEnvironment/Surface/proc/remove.h>
#import <LindChain/ProcEnvironment/Surface/proc/rw.h>
#include <stdatomic.h>

ksurface_return_t proc_remove_by_pid(pid_t pid)
{
    /*
     * locking process table so the process table, can
     * be safely edited.
     */
    proc_table_write_lock();
    
    /*
     * remocing process from radix tree, which is also
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
        /* reverting locks and return */
        proc_table_unlock();
        return kSurfaceReturnNotFound;
    }
    
    /*
     * decrementing count of processes so its
     * correctly counted.
     */
    ksurface->proc_info.proc_count--;
    
    /*
     * invalidating object and remocing its
     * origin reference that lived in the
     * radix tree.
     */
    kvo_invalidate(proc);
    kvo_release(proc);
    
    /* reverting locks and return */
    proc_table_unlock();
    return kSurfaceReturnSuccess;
}
