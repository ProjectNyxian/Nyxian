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
#import <LindChain/ProcEnvironment/Surface/tty/lookup.h>

ksurface_return_t tty_for_handle(uint64_t handle,
                                 ksurface_tty_t **tty)
{
    /* sanity check */
    if(tty == NULL)
    {
        return SURFACE_NULLPTR;
    }
    
    /* tty lookup */
    tty_table_rdlock();
    *tty = radix_lookup(&(ksurface->tty_info.tty), handle);
    tty_table_unlock();
    
    /*
     * caller expects retained tty object, so
     * attempting to retain it and if it doesnt work
     * returning with an error.
     */
    if(*tty == NULL ||
       !kvo_retain(*tty))
    {
        return SURFACE_RETAIN_FAILED;
    }
    
    return SURFACE_SUCCESS;
}
