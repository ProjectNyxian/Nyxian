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

#import <LindChain/ProcEnvironment/Surface/proc/find.h>
#import <LindChain/ProcEnvironment/Surface/proc/def.h>
#include <stdatomic.h>

ksurface_proc_t *proc_for_pid(pid_t pid)
{
    proc_table_rdlock();
    ksurface_proc_t *proc = radix_lookup(&(ksurface->proc_info.tree), pid);
    proc_table_unlock();
    
    if(proc == NULL ||
       kvo_retain(proc))
    {
        return proc;
    }
    
    return NULL;
}
