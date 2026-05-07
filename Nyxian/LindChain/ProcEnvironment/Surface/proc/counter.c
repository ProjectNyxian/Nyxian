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

#include <LindChain/ProcEnvironment/Surface/proc/counter.h>
#include <LindChain/ProcEnvironment/Surface/surface.h>
#include <stdatomic.h>

static atomic_int counter = 0;

bool proc_count(void)
{
    int old = atomic_fetch_add(&counter, 1);
    if(old >= PROC_MAX)
    {
        atomic_fetch_sub(&counter, 1);
        return false;
    }
    return true;
}

void proc_uncount(void)
{
    atomic_fetch_sub(&counter, 1);
}
