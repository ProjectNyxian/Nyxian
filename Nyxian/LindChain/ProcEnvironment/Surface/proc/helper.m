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

#import <LindChain/ProcEnvironment/Surface/surface.h>
#import <LindChain/ProcEnvironment/Surface/proc/helper.h>
#import <LindChain/ProcEnvironment/panic.h>

void proc_helper_lock(bool wantLock)
{
    if(!wantLock && !seqlock_is_locked(&(surface->seqlock)))
    {
        environment_panic();
    }
    else if(wantLock)
    {
        seqlock_lock(&(surface->seqlock));
    }
}

void proc_helper_unlock(bool wantLock)
{
    if(wantLock)
    {
        seqlock_unlock(&(surface->seqlock));
    }
}

unsigned long proc_helper_read_begin(bool wantLock)
{
    if(!wantLock && !seqlock_is_locked(&(surface->seqlock)))
    {
        environment_panic();
    }
    if(wantLock)
    {
        return seqlock_read_begin(&(surface->seqlock));
    }
    else
    {
        return 0;
    }
}

bool proc_helper_read_retry(bool wantLock,
                            unsigned long seq)
{
    if(wantLock)
    {
        return seqlock_read_retry(&(surface->seqlock), seq);
    }
    else
    {
        return false;
    }
}
