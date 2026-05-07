/*
 SPDX-License-Identifier: AGPL-3.0-or-later

 Copyright (C) 2025 - 2026 mach-port-t

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

#include <LindChain/ProcEnvironment/Surface/proc/remove.h>

kern_return_t proc_remove_by_pid(pid_t pid)
{
    /*
     * removing process from radix tree, which is also
     * where its first reference lives at.
     */
    proc_table_wrlock();
    ksurface_proc_t *proc = radix_remove(&(ksurface->proc_info.tree), pid);
    
    /*
     * radix_remove always returns the process
     * structure, that previously was inserted at that
     * pid slot. if its NULL it means there was never a
     * pid so this is also a was process in tree check.
     */
    if(proc == NULL)
    {
        proc_table_unlock();
        return KERN_NO_ACCESS;
    }
    
    /*
     * decrementing count of processes so its
     * correctly counted.
     */
    ksurface->proc_info.proc_count--;
    proc_table_unlock();
    
    /*
     * invalidating object and removing its
     * origin reference that lived in the
     * radix tree.
     */
    kvo_invalidate(proc);
    kvo_release(proc);

    return KERN_SUCCESS;
}
